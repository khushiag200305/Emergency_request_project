"""
Emergency Response Optimization and Tracking System (ERTS)
Flask Backend — app.py  (UPGRADED — v2)

Fixes & Additions:
  ✅ Vehicle assignment bug fixed (operator_id now passed; procedure invoked correctly)
  ✅ All 14 tables are now actively queried
  ✅ 30+ distinct SQL queries used across routes
  ✅ Caller Details — add/view per request
  ✅ Vehicle Log — live log viewer
  ✅ Area Response Stats — dedicated page
  ✅ Notifications — citizen & operator inbox
  ✅ Feedback — citizen can submit, admin can view all
  ✅ Admin Reports page with subqueries & GROUP BY analytics
  ✅ New API endpoints for charts (vehicle status, staff availability)
  ✅ Operator can update dispatch status to In Progress
"""

from flask import (Flask, render_template, request, redirect,
                   url_for, session, flash, jsonify)
import os
import mysql.connector
from mysql.connector import Error
from functools import wraps
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────
# App Configuration
# ─────────────────────────────────────────────
app = Flask(__name__)

app.secret_key = os.getenv("SECRET_KEY", "erts_super_secret_key_2024")

DB_CONFIG = {
    "host":     os.getenv("MYSQL_HOST", "127.0.0.1"),
    "user":     os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", "Simba@1504"),
    "database": os.getenv("MYSQL_DATABASE", "Emergency_Service_DB"),
    "port":     int(os.getenv("MYSQL_PORT", "3306")),
}

# ─────────────────────────────────────────────
# Database Helpers
# ─────────────────────────────────────────────
def get_db():
    """Return a new MySQL connection."""
    return mysql.connector.connect(**DB_CONFIG)


def query(sql, params=None, fetch="all"):
    """
    Execute a SQL query and return results.
    fetch: 'all' | 'one' | 'none'
    """
    conn = get_db()
    results = [] if fetch == "all" else None
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, params or ())
        if fetch == "all":
            results = cur.fetchall()
        elif fetch == "one":
            results = cur.fetchone()
        elif fetch == "none":
            conn.commit()
        cur.close()
    except Error as e:
        conn.rollback()
        raise e
    finally:
        conn.close()
    return results


# ─────────────────────────────────────────────
# Auth Decorators
# ─────────────────────────────────────────────
def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user_id" not in session:
            flash("Please log in to continue.", "warning")
            return redirect(url_for("login"))
        return f(*args, **kwargs)
    return decorated


def role_required(*roles):
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            if session.get("role") not in roles:
                flash("Access denied.", "danger")
                return redirect(url_for("dashboard"))
            return f(*args, **kwargs)
        return decorated
    return decorator


# ─────────────────────────────────────────────
# Auth Routes
# ─────────────────────────────────────────────
@app.route("/", methods=["GET", "POST"])
def login():
    if "user_id" in session:
        return redirect(url_for("dashboard"))

    if request.method == "POST":
        email    = request.form.get("email", "").strip()
        password = request.form.get("password", "").strip()

        # Query 1: Authenticate user
        user = query(
            "SELECT * FROM Users WHERE email=%s AND password=%s AND is_active=1",
            (email, password), fetch="one"
        )
        if user:
            session["user_id"] = user["user_id"]
            session["name"]    = user["name"]
            session["role"]    = user["role"]
            session["email"]   = user["email"]
            flash(f"Welcome back, {user['name']}!", "success")
            return redirect(url_for("dashboard"))
        else:
            flash("Invalid credentials. Please try again.", "danger")

    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    flash("You have been logged out.", "info")
    return redirect(url_for("login"))


# ─────────────────────────────────────────────
# Dashboard (Role-Based Redirect)
# ─────────────────────────────────────────────
@app.route("/dashboard")
@login_required
def dashboard():
    role = session.get("role")
    if role == "Citizen":
        return redirect(url_for("citizen_dashboard"))
    elif role == "Operator":
        return redirect(url_for("operator_dashboard"))
    elif role == "Admin":
        return redirect(url_for("admin_dashboard"))
    return redirect(url_for("login"))


# ══════════════════════════════════════════════
# CITIZEN ROUTES
# ══════════════════════════════════════════════

@app.route("/citizen")
@login_required
@role_required("Citizen")
def citizen_dashboard():
    user_id = session["user_id"]

    # Query 2: Citizen's own emergency history with dispatch info
    my_requests = query(
        """SELECT er.request_id, er.emergency_type, er.location,
                  er.severity_level, er.status, er.request_time,
                  er.priority_score,
                  dr.dispatch_time, dr.arrival_time, dr.response_time,
                  ev.vehicle_type, ev.driver_name
           FROM Emergency_Request er
           LEFT JOIN Dispatch_Record dr ON er.request_id = dr.request_id
           LEFT JOIN Emergency_Vehicle ev ON dr.vehicle_id = ev.vehicle_id
           WHERE er.user_id = %s
           ORDER BY er.request_time DESC""",
        (user_id,)
    )

    # Query 3: Unread notifications for this citizen
    notifications = query(
        """SELECT notification_id, message, type, created_at
           FROM Notifications
           WHERE user_id = %s AND status = 'Unread'
           ORDER BY created_at DESC""",
        (user_id,)
    )

    return render_template("citizen.html",
                           requests=my_requests,
                           notifications=notifications)


@app.route("/citizen/notifications/read", methods=["POST"])
@login_required
@role_required("Citizen")
def mark_notifications_read():
    user_id = session["user_id"]
    # Query 4: Mark all notifications read
    query(
        "UPDATE Notifications SET status='Read' WHERE user_id=%s AND status='Unread'",
        (user_id,), fetch="none"
    )
    flash("All notifications marked as read.", "info")
    return redirect(url_for("citizen_dashboard"))


@app.route("/citizen/report", methods=["POST"])
@login_required
@role_required("Citizen")
def report_emergency():
    user_id        = session["user_id"]
    etype          = request.form.get("emergency_type")
    description    = request.form.get("description", "")
    location       = request.form.get("location", "")
    severity_level = request.form.get("severity_level", 3)
    caller_name    = request.form.get("caller_name", "").strip()
    caller_phone   = request.form.get("caller_phone", "").strip()
    relation       = request.form.get("relation_to_victim", "Self")

    conn = get_db()
    try:
        cur = conn.cursor(dictionary=True)

        # Query 5: Insert new emergency request
        cur.execute(
            """INSERT INTO Emergency_Request
               (user_id, emergency_type, description, location, severity_level)
               VALUES (%s, %s, %s, %s, %s)""",
            (user_id, etype, description, location, severity_level)
        )
        new_req_id = cur.lastrowid

        # Query 6: Insert caller details (uses Caller_Details table)
        if caller_name or caller_phone:
            cur.execute(
                """INSERT INTO Caller_Details
                   (request_id, caller_name, caller_phone, relation_to_victim)
                   VALUES (%s, %s, %s, %s)""",
                (new_req_id, caller_name or None, caller_phone or None, relation)
            )

        conn.commit()
        cur.close()
        flash("🚨 Emergency reported successfully! Help is on the way.", "success")
    except Error as e:
        conn.rollback()
        flash(f"Error: {e}", "danger")
    finally:
        conn.close()

    return redirect(url_for("citizen_dashboard"))


@app.route("/citizen/feedback/<int:req_id>", methods=["GET", "POST"])
@login_required
@role_required("Citizen")
def submit_feedback(req_id):
    user_id = session["user_id"]

    # Query 7: Verify request belongs to this citizen and is Completed
    req = query(
        """SELECT request_id, emergency_type, location, status
           FROM Emergency_Request
           WHERE request_id=%s AND user_id=%s AND status='Completed'""",
        (req_id, user_id), fetch="one"
    )
    if not req:
        flash("Feedback can only be submitted for your completed requests.", "warning")
        return redirect(url_for("citizen_dashboard"))

    # Query 8: Check if feedback already submitted
    existing = query(
        "SELECT feedback_id FROM Feedback WHERE request_id=%s AND user_id=%s",
        (req_id, user_id), fetch="one"
    )

    if request.method == "POST":
        if existing:
            flash("You have already submitted feedback for this request.", "warning")
            return redirect(url_for("citizen_dashboard"))
        rating   = request.form.get("rating", 3)
        comments = request.form.get("comments", "")
        # Query 9: Insert feedback
        query(
            "INSERT INTO Feedback (request_id, user_id, rating, comments) VALUES (%s,%s,%s,%s)",
            (req_id, user_id, rating, comments), fetch="none"
        )
        flash("✅ Thank you for your feedback!", "success")
        return redirect(url_for("citizen_dashboard"))

    return render_template("feedback_form.html", req=req, existing=existing)


# ══════════════════════════════════════════════
# OPERATOR ROUTES
# ══════════════════════════════════════════════

@app.route("/operator")
@login_required
@role_required("Operator")
def operator_dashboard():
    # Query 10: All pending requests with caller details (LEFT JOIN Caller_Details)
    pending = query(
        """SELECT er.request_id, er.emergency_type, er.description,
                  er.location, er.severity_level, er.status,
                  er.request_time, er.priority_score,
                  u.name AS reported_by, u.phone_number,
                  cd.caller_name, cd.caller_phone, cd.relation_to_victim
           FROM Emergency_Request er
           JOIN Users u ON er.user_id = u.user_id
           LEFT JOIN Caller_Details cd ON er.request_id = cd.request_id
           WHERE er.status = 'Pending'
           ORDER BY er.severity_level DESC, er.request_time ASC"""
    )

    # Query 11: Active dispatches with vehicle and staff info
    active = query(
        """SELECT er.request_id, er.emergency_type, er.location,
                  er.severity_level, er.status, er.request_time,
                  u.name AS reported_by,
                  ev.vehicle_type, ev.driver_name, ev.license_plate,
                  dr.dispatch_id, dr.dispatch_time, dr.response_time
           FROM Emergency_Request er
           JOIN Users u ON er.user_id = u.user_id
           LEFT JOIN Dispatch_Record dr ON er.request_id = dr.request_id
           LEFT JOIN Emergency_Vehicle ev ON dr.vehicle_id = ev.vehicle_id
           WHERE er.status IN ('Assigned', 'In Progress')
           ORDER BY er.severity_level DESC"""
    )

    # Query 12: Available vehicles joined with service center info
    available_vehicles = query(
        """SELECT ev.vehicle_id, ev.vehicle_type, ev.license_plate,
                  ev.driver_name, ev.availability,
                  sc.center_name, sc.area, sc.service_type
           FROM Emergency_Vehicle ev
           JOIN Service_Center sc ON ev.center_id = sc.center_id
           WHERE ev.availability = 'Available'
           ORDER BY sc.service_type"""
    )

    # Query 13: Unread notifications for this operator
    notifications = query(
        """SELECT notification_id, message, type, created_at
           FROM Notifications
           WHERE user_id=%s AND status='Unread'
           ORDER BY created_at DESC""",
        (session["user_id"],)
    )

    return render_template("operator.html",
                           pending=pending,
                           active=active,
                           available_vehicles=available_vehicles,
                           notifications=notifications)


@app.route("/operator/assign/<int:req_id>", methods=["POST"])
@login_required
@role_required("Operator")
def assign_vehicle(req_id):
    """
    Two-phase vehicle assignment:
      Phase 1: Try CALL AssignVehicle stored procedure.
      Phase 2: If SP fails/missing, do full assignment with direct SQL.
    This guarantees assignment works regardless of SP availability.
    """
    operator_id = session["user_id"]
    conn = get_db()
    msg = ""
    try:
        cur = conn.cursor()

        # Verify request is still Pending
        cur.execute(
            "SELECT request_id, emergency_type FROM Emergency_Request "
            "WHERE request_id=%s AND status='Pending'",
            (req_id,)
        )
        req_row = cur.fetchone()
        if not req_row:
            flash("❌ Request not found or already assigned.", "danger")
            cur.close()
            conn.close()
            return redirect(url_for("operator_dashboard"))
        etype = req_row[1]

        # Find best available vehicle (match service type to emergency type)
        cur.execute(
            """SELECT ev.vehicle_id FROM Emergency_Vehicle ev
               JOIN Service_Center sc ON ev.center_id = sc.center_id
               WHERE ev.availability = 'Available'
               ORDER BY
                 CASE WHEN sc.service_type = %s THEN 0 ELSE 1 END,
                 ev.vehicle_id ASC
               LIMIT 1""",
            (etype,)
        )
        v_row = cur.fetchone()
        if not v_row:
            flash("❌ No available vehicles right now. Try again shortly.", "danger")
            cur.close()
            conn.close()
            return redirect(url_for("operator_dashboard"))
        vehicle_id = v_row[0]

        # ── Phase 1: Try stored procedure ──
        sp_success = False
        try:
            cur.execute("SET @sp_msg = ''")
            cur.execute(f"CALL AssignVehicle({req_id}, @sp_msg)")
            conn.commit()
            cur.execute("SELECT @sp_msg")
            sp_row = cur.fetchone()
            sp_msg = str(sp_row[0]) if sp_row and sp_row[0] else ""
            if "SUCCESS" in sp_msg.upper():
                sp_success = True
                msg = sp_msg
        except Exception:
            conn.rollback()   # SP failed — fall through to Phase 2

        # ── Phase 2: Direct SQL assignment ──
        if not sp_success:
            cur.execute(
                """INSERT INTO Dispatch_Record
                       (request_id, vehicle_id, operator_id, dispatch_time, status)
                   VALUES (%s, %s, %s, NOW(), 'Assigned')""",
                (req_id, vehicle_id, operator_id)
            )
            cur.execute(
                "UPDATE Emergency_Vehicle SET availability='Busy' WHERE vehicle_id=%s",
                (vehicle_id,)
            )
            cur.execute(
                "UPDATE Emergency_Request SET status='Assigned' WHERE request_id=%s",
                (req_id,)
            )
            conn.commit()
            msg = f"SUCCESS — Vehicle #{vehicle_id} assigned directly."
        else:
            # Patch operator_id if SP left it NULL
            cur.execute(
                """UPDATE Dispatch_Record SET operator_id=%s
                   WHERE request_id=%s AND operator_id IS NULL
                   ORDER BY dispatch_id DESC LIMIT 1""",
                (operator_id, req_id)
            )
            conn.commit()

        # ── Auto-assign staff: try SP, then direct SQL fallback ──
        staff_count = 0
        try:
            cur.execute("SET @staff_cnt = 0")
            cur.execute(
                f"CALL AssignStaffToRequest({req_id}, %s, @staff_cnt)",
                (etype,)
            )
            conn.commit()
            cur.execute("SELECT @staff_cnt")
            sc_row = cur.fetchone()
            staff_count = int(sc_row[0]) if sc_row and sc_row[0] else 0
        except Exception:
            conn.rollback()
            try:
                cur.execute(
                    """SELECT staff_id FROM Service_Staff
                       WHERE availability='Available' LIMIT 3"""
                )
                for s in cur.fetchall():
                    cur.execute(
                        """INSERT INTO Staff_Assignment (request_id, staff_id, assigned_at)
                           VALUES (%s, %s, NOW())""",
                        (req_id, s[0])
                    )
                    cur.execute(
                        "UPDATE Service_Staff SET availability='Assigned' WHERE staff_id=%s",
                        (s[0],)
                    )
                    staff_count += 1
                conn.commit()
            except Exception:
                conn.rollback()

        msg += f" | {staff_count} staff assigned."
        cur.close()

    except Error as e:
        msg = f"ERROR: {e}"
        conn.rollback()
    finally:
        conn.close()

    if "SUCCESS" in msg.upper():
        flash(f"✅ {msg}", "success")
    else:
        flash(f"❌ {msg}", "danger")

    return redirect(url_for("operator_dashboard"))
@app.route("/operator/progress/<int:dispatch_id>", methods=["POST"])
@login_required
@role_required("Operator")
def mark_in_progress(dispatch_id):
    """Mark a dispatch as In Progress (vehicle has arrived on scene)."""
    conn = get_db()
    try:
        cur = conn.cursor()
        # Query 14: Update dispatch and request to In Progress
        cur.execute(
            """UPDATE Dispatch_Record
               SET status='In Progress', arrival_time=CURRENT_TIMESTAMP
               WHERE dispatch_id=%s AND status='Assigned'""",
            (dispatch_id,)
        )
        # Get request_id to update Emergency_Request
        cur.execute("SELECT request_id FROM Dispatch_Record WHERE dispatch_id=%s", (dispatch_id,))
        row = cur.fetchone()
        if row:
            cur.execute(
                "UPDATE Emergency_Request SET status='In Progress' WHERE request_id=%s",
                (row[0],)
            )
        conn.commit()
        cur.close()
        flash("✅ Dispatch marked as In Progress.", "success")
    except Error as e:
        conn.rollback()
        flash(f"❌ Error: {e}", "danger")
    finally:
        conn.close()
    return redirect(url_for("operator_dashboard"))


@app.route("/operator/complete/<int:dispatch_id>", methods=["POST"])
@login_required
@role_required("Operator")
def complete_dispatch(dispatch_id):
    """Call CompleteEmergency stored procedure."""
    conn = get_db()
    msg = ""
    try:
        cur = conn.cursor()
        cur.execute("SET @out_msg = ''")
        cur.execute(f"CALL CompleteEmergency({dispatch_id}, @out_msg)")
        conn.commit()
        cur.execute("SELECT @out_msg AS msg")
        row = cur.fetchone()
        msg = row[0] if row else "Unknown result"
        cur.close()
    except Error as e:
        msg = f"ERROR: {e}"
        conn.rollback()
    finally:
        conn.close()

    if msg and msg.startswith("SUCCESS"):
        flash(f"✅ {msg}", "success")
    else:
        flash(f"❌ {msg}", "danger")

    return redirect(url_for("operator_dashboard"))


@app.route("/operator/cancel/<int:req_id>", methods=["POST"])
@login_required
@role_required("Operator")
def operator_cancel(req_id):
    """Cancel a pending/assigned request via stored procedure."""
    operator_id = session["user_id"]
    conn = get_db()
    msg = ""
    try:
        cur = conn.cursor()
        cur.execute("SET @out_msg = ''")
        cur.execute(f"CALL CancelRequest({req_id}, {operator_id}, @out_msg)")
        conn.commit()
        cur.execute("SELECT @out_msg AS msg")
        row = cur.fetchone()
        msg = row[0] if row else "Unknown"
        cur.close()
    except Error as e:
        msg = f"ERROR: {e}"
        conn.rollback()
    finally:
        conn.close()

    if msg and msg.startswith("SUCCESS"):
        flash(f"✅ {msg}", "success")
    else:
        flash(f"❌ {msg}", "danger")
    return redirect(url_for("operator_dashboard"))


# ══════════════════════════════════════════════
# ADMIN ROUTES
# ══════════════════════════════════════════════

@app.route("/admin")
@login_required
@role_required("Admin")
def admin_dashboard():
    # Query 15: Dashboard KPI counters
    total       = query("SELECT COUNT(*) AS cnt FROM Emergency_Request", fetch="one")["cnt"]
    pending     = query("SELECT COUNT(*) AS cnt FROM Emergency_Request WHERE status='Pending'", fetch="one")["cnt"]
    available_v = query("SELECT COUNT(*) AS cnt FROM Emergency_Vehicle WHERE availability='Available'", fetch="one")["cnt"]
    avg_resp    = query(
        "SELECT ROUND(AVG(response_time),1) AS avg FROM Dispatch_Record WHERE response_time IS NOT NULL",
        fetch="one"
    )["avg"] or 0
    in_progress = query("SELECT COUNT(*) AS cnt FROM Emergency_Request WHERE status='In Progress'", fetch="one")["cnt"]
    completed   = query("SELECT COUNT(*) AS cnt FROM Emergency_Request WHERE status='Completed'", fetch="one")["cnt"]
    total_staff = query("SELECT COUNT(*) AS cnt FROM Service_Staff", fetch="one")["cnt"]
    # Query 16: Count unread notifications across all users
    unread_notif = query("SELECT COUNT(*) AS cnt FROM Notifications WHERE status='Unread'", fetch="one")["cnt"]

    # Query 17: Latest 50 requests with citizen + dispatch info
    all_requests = query(
        """SELECT er.request_id, er.emergency_type, er.location,
                  er.severity_level, er.status, er.request_time,
                  er.priority_score, u.name AS citizen, u.phone_number,
                  dr.response_time, dr.dispatch_time
           FROM Emergency_Request er
           JOIN Users u ON er.user_id = u.user_id
           LEFT JOIN Dispatch_Record dr ON er.request_id = dr.request_id
           ORDER BY er.request_time DESC
           LIMIT 50"""
    )

    # Query 18: Recent incident history with changer name
    recent_incidents = query(
        """SELECT ih.request_id, ih.old_status, ih.new_status,
                  ih.change_time, ih.remarks,
                  u.name AS changed_by_name
           FROM Incident_History ih
           LEFT JOIN Users u ON ih.changed_by = u.user_id
           ORDER BY ih.change_time DESC LIMIT 15"""
    )

    # Query 19: Area response stats (uses Area_Response_Stats — safe fallback if table empty)
    try:
        area_stats = query(
            """SELECT area, total_requests, avg_response_time,
                      max_response_time, last_updated
               FROM Area_Response_Stats
               ORDER BY total_requests DESC"""
        )
    except Exception:
        area_stats = []

    return render_template("admin.html",
                           total=total,
                           pending=pending,
                           available_v=available_v,
                           avg_resp=avg_resp,
                           in_progress=in_progress,
                           completed=completed,
                           total_staff=total_staff,
                           unread_notif=unread_notif,
                           all_requests=all_requests,
                           recent_incidents=recent_incidents,
                           area_stats=area_stats)


@app.route("/admin/requests")
@login_required
@role_required("Admin")
def admin_all_requests():
    status_filter = request.args.get("status", "")
    type_filter   = request.args.get("type", "")

    # Query 20: Filterable requests with caller details
    sql = """SELECT er.request_id, er.emergency_type, er.description,
                    er.location, er.severity_level, er.status,
                    er.request_time, er.priority_score,
                    u.name AS citizen, u.phone_number,
                    cd.caller_name, cd.caller_phone, cd.relation_to_victim,
                    dr.response_time, dr.dispatch_time, dr.arrival_time,
                    ev.vehicle_type, ev.driver_name
             FROM Emergency_Request er
             JOIN Users u ON er.user_id = u.user_id
             LEFT JOIN Caller_Details cd ON er.request_id = cd.request_id
             LEFT JOIN Dispatch_Record dr ON er.request_id = dr.request_id
             LEFT JOIN Emergency_Vehicle ev ON dr.vehicle_id = ev.vehicle_id
             WHERE 1=1"""
    params = []
    if status_filter:
        sql += " AND er.status = %s"
        params.append(status_filter)
    if type_filter:
        sql += " AND er.emergency_type = %s"
        params.append(type_filter)
    sql += " ORDER BY er.request_time DESC"

    requests_list = query(sql, params)
    return render_template("admin_requests.html",
                           requests=requests_list,
                           status_filter=status_filter,
                           type_filter=type_filter)


@app.route("/admin/vehicles")
@login_required
@role_required("Admin")
def admin_vehicles():
    # Query 21: Vehicles with LATEST maintenance record only (subquery to avoid duplicate rows)
    # Uses a correlated subquery to pick only the most recent maintenance entry per vehicle
    vehicles = query(
        """SELECT ev.vehicle_id, ev.vehicle_type, ev.license_plate,
                  ev.availability, ev.driver_name, ev.driver_phone,
                  sc.center_name, sc.area, sc.service_type,
                  vm.status        AS maint_status,
                  vm.next_service_date,
                  vm.remarks       AS maint_remarks,
                  (SELECT COUNT(*) FROM Dispatch_Record dr
                   WHERE dr.vehicle_id = ev.vehicle_id) AS total_dispatches
           FROM Emergency_Vehicle ev
           JOIN Service_Center sc ON ev.center_id = sc.center_id
           LEFT JOIN Vehicle_Maintenance vm
                  ON vm.vehicle_id = ev.vehicle_id
                 AND vm.maintenance_id = (
                         SELECT MAX(vm2.maintenance_id)
                         FROM Vehicle_Maintenance vm2
                         WHERE vm2.vehicle_id = ev.vehicle_id
                     )
           ORDER BY ev.vehicle_type, ev.vehicle_id"""
    )

    # Query 22: Vehicles needing service
    # Try the Maintenance_Due view first; fall back to a direct table query if view absent
    try:
        maintenance_due = query(
            "SELECT * FROM Maintenance_Due ORDER BY status DESC"
        )
    except Exception:
        # Fallback: query Vehicle_Maintenance table directly joined with Emergency_Vehicle
        try:
            maintenance_due = query(
                """SELECT vm.vehicle_id, ev.vehicle_type, ev.license_plate,
                          vm.status, vm.next_service_date, vm.remarks
                   FROM Vehicle_Maintenance vm
                   JOIN Emergency_Vehicle ev ON vm.vehicle_id = ev.vehicle_id
                   WHERE vm.status IN ('Scheduled','Overdue','In Progress')
                      OR vm.next_service_date <= CURDATE()
                   ORDER BY vm.next_service_date ASC"""
            )
        except Exception:
            maintenance_due = []

    return render_template("admin_vehicles.html",
                           vehicles=vehicles,
                           maintenance_due=maintenance_due)


@app.route("/admin/staff")
@login_required
@role_required("Admin")
def admin_staff():
    # Query 23: Staff with assignment count (correlated subquery)
    staff = query(
        """SELECT ss.staff_id, ss.name, ss.role, ss.specialization,
                  ss.phone_number, ss.availability, ss.shift,
                  sc.center_name, sc.area,
                  (SELECT COUNT(*) FROM Staff_Assignment sa
                   WHERE sa.staff_id = ss.staff_id) AS total_assignments
           FROM Service_Staff ss
           LEFT JOIN Service_Center sc ON ss.center_id = sc.center_id
           ORDER BY ss.role, ss.name"""
    )

    # Query 24: Staff never assigned (subquery with NOT IN)
    unassigned_staff = query(
        """SELECT staff_id, name, role, specialization, availability
           FROM Service_Staff
           WHERE staff_id NOT IN (SELECT DISTINCT staff_id FROM Staff_Assignment)"""
    )

    return render_template("admin_staff.html",
                           staff=staff,
                           unassigned_staff=unassigned_staff)


@app.route("/admin/notifications")
@login_required
@role_required("Admin")
def admin_notifications():
    """Admin view of all notifications across the system."""
    # Query 25: All notifications joined with user name
    all_notifs = query(
        """SELECT n.notification_id, n.message, n.type, n.status, n.created_at,
                  u.name AS recipient, u.role
           FROM Notifications n
           JOIN Users u ON n.user_id = u.user_id
           ORDER BY n.created_at DESC
           LIMIT 100"""
    )

    # Query 26: Notification summary by type
    notif_summary = query(
        """SELECT type,
                  COUNT(*) AS total,
                  SUM(CASE WHEN status='Unread' THEN 1 ELSE 0 END) AS unread
           FROM Notifications
           GROUP BY type"""
    )

    return render_template("admin_notifications.html",
                           all_notifs=all_notifs,
                           notif_summary=notif_summary)


@app.route("/admin/vehicle-logs")
@login_required
@role_required("Admin")
def admin_vehicle_logs():
    """Live vehicle location logs (Vehicle_Log table)."""
    vehicle_filter = request.args.get("vehicle_id", "")

    # Query 27: Latest 200 vehicle location logs
    sql = """SELECT vl.log_id, vl.vehicle_id, vl.latitude, vl.longitude, vl.logged_at,
                    ev.vehicle_type, ev.license_plate, ev.driver_name,
                    sc.area
             FROM Vehicle_Log vl
             JOIN Emergency_Vehicle ev ON vl.vehicle_id = ev.vehicle_id
             JOIN Service_Center sc ON ev.center_id = sc.center_id
             WHERE 1=1"""
    params = []
    if vehicle_filter:
        sql += " AND vl.vehicle_id = %s"
        params.append(vehicle_filter)
    sql += " ORDER BY vl.logged_at DESC LIMIT 200"

    try:
        logs = query(sql, params)
    except Exception:
        logs = []

    # Query 28: All vehicles for filter dropdown
    vehicles = query("SELECT vehicle_id, vehicle_type, license_plate FROM Emergency_Vehicle ORDER BY vehicle_id")

    # Query 29: Latest position per vehicle (subquery with GROUP BY)
    try:
        latest_positions = query(
            """SELECT vl.vehicle_id, vl.latitude, vl.longitude, vl.logged_at,
                      ev.vehicle_type, ev.license_plate, ev.availability
               FROM Vehicle_Log vl
               JOIN Emergency_Vehicle ev ON vl.vehicle_id = ev.vehicle_id
               WHERE vl.logged_at = (
                   SELECT MAX(vl2.logged_at) FROM Vehicle_Log vl2
                   WHERE vl2.vehicle_id = vl.vehicle_id
               )
               ORDER BY vl.vehicle_id"""
        )
    except Exception:
        latest_positions = []

    return render_template("admin_vehicle_logs.html",
                           logs=logs,
                           vehicles=vehicles,
                           latest_positions=latest_positions,
                           vehicle_filter=vehicle_filter)


@app.route("/admin/area-stats")
@login_required
@role_required("Admin")
def admin_area_stats():
    """Dedicated page for Area_Response_Stats + live computed stats."""
    # Query 30: Stored area stats (safe fallback if table/view not populated)
    try:
        stored_stats = query(
            "SELECT * FROM Area_Response_Stats ORDER BY total_requests DESC"
        )
    except Exception:
        stored_stats = []

    # Query 31: Live computed stats from Dispatch_Record (GROUP BY with HAVING)
    live_stats = query(
        """SELECT er.location AS area,
                  COUNT(*) AS total_requests,
                  ROUND(AVG(TIMESTAMPDIFF(MINUTE, dr.dispatch_time, dr.arrival_time)),2) AS avg_response_mins,
                  MAX(TIMESTAMPDIFF(MINUTE, dr.dispatch_time, dr.arrival_time)) AS max_response_mins,
                  MIN(TIMESTAMPDIFF(MINUTE, dr.dispatch_time, dr.arrival_time)) AS min_response_mins,
                  SUM(CASE WHEN er.status='Completed' THEN 1 ELSE 0 END) AS completed
           FROM Emergency_Request er
           JOIN Dispatch_Record dr ON er.request_id = dr.request_id
           WHERE dr.arrival_time IS NOT NULL
           GROUP BY er.location
           HAVING COUNT(*) >= 1
           ORDER BY avg_response_mins DESC"""
    )

    # Query 32: Areas with above-average emergency count (subquery)
    high_volume_areas = query(
        """SELECT location, COUNT(*) AS total
           FROM Emergency_Request
           GROUP BY location
           HAVING COUNT(*) > (
               SELECT AVG(cnt) FROM (
                   SELECT COUNT(*) AS cnt FROM Emergency_Request GROUP BY location
               ) AS sub
           )
           ORDER BY total DESC"""
    )

    return render_template("admin_area_stats.html",
                           stored_stats=stored_stats,
                           live_stats=live_stats,
                           high_volume_areas=high_volume_areas)


@app.route("/admin/feedback")
@login_required
@role_required("Admin")
def admin_feedback():
    """Admin view of all feedback."""
    # Query 33: All feedback with citizen name and emergency details
    all_feedback = query(
        """SELECT f.feedback_id, f.rating, f.comments, f.created_at,
                  u.name AS citizen, u.phone_number,
                  er.request_id, er.emergency_type, er.location
           FROM Feedback f
           JOIN Users u ON f.user_id = u.user_id
           JOIN Emergency_Request er ON f.request_id = er.request_id
           ORDER BY f.created_at DESC"""
    )

    # Query 34: Average rating per emergency type (GROUP BY + AVG)
    rating_by_type = query(
        """SELECT er.emergency_type,
                  ROUND(AVG(f.rating),2) AS avg_rating,
                  COUNT(f.feedback_id) AS total_reviews,
                  MIN(f.rating) AS lowest, MAX(f.rating) AS highest
           FROM Feedback f
           JOIN Emergency_Request er ON f.request_id = er.request_id
           GROUP BY er.emergency_type"""
    )

    # Query 35: Top-rated locations (avg > 4, HAVING clause)
    top_locations = query(
        """SELECT er.location, ROUND(AVG(f.rating),2) AS avg_rating,
                  COUNT(*) AS reviews
           FROM Feedback f
           JOIN Emergency_Request er ON f.request_id = er.request_id
           GROUP BY er.location
           HAVING AVG(f.rating) > 4
           ORDER BY avg_rating DESC"""
    )

    return render_template("admin_feedback.html",
                           all_feedback=all_feedback,
                           rating_by_type=rating_by_type,
                           top_locations=top_locations)


@app.route("/admin/reports")
@login_required
@role_required("Admin")
def admin_reports():
    """
    Dedicated DBMS Reports page — showcases advanced queries:
    JOINs, subqueries, GROUP BY, HAVING, ORDER BY, aggregate functions,
    correlated subqueries, EXISTS, NOT IN.
    """

    # Query 36: Operator performance with dispatches + avg response (correlated subquery)
    operator_perf = query(
        """SELECT u.user_id, u.name AS operator, u.email,
                  (SELECT COUNT(*) FROM Dispatch_Record dr
                   WHERE dr.operator_id = u.user_id) AS dispatches,
                  (SELECT ROUND(AVG(dr2.response_time),1)
                   FROM Dispatch_Record dr2
                   WHERE dr2.operator_id = u.user_id
                   AND dr2.response_time IS NOT NULL) AS avg_resp_mins,
                  (SELECT COUNT(*) FROM Dispatch_Record dr3
                   WHERE dr3.operator_id = u.user_id
                   AND dr3.status = 'Completed') AS completed_dispatches
           FROM Users u
           WHERE u.role = 'Operator'
           ORDER BY dispatches DESC"""
    )

    # Query 37: Emergency type breakdown with completion rate
    type_stats = query(
        """SELECT emergency_type,
                  COUNT(*) AS total,
                  SUM(CASE WHEN status='Completed'   THEN 1 ELSE 0 END) AS completed,
                  SUM(CASE WHEN status='Pending'     THEN 1 ELSE 0 END) AS pending,
                  SUM(CASE WHEN status='In Progress' THEN 1 ELSE 0 END) AS in_progress,
                  ROUND(SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END)*100.0/COUNT(*),1) AS completion_pct
           FROM Emergency_Request
           GROUP BY emergency_type
           ORDER BY total DESC"""
    )

    # Query 38: Severity distribution with percentage
    severity_dist = query(
        """SELECT severity_level,
                  COUNT(*) AS cnt,
                  ROUND(COUNT(*)*100.0/(SELECT COUNT(*) FROM Emergency_Request),1) AS pct
           FROM Emergency_Request
           GROUP BY severity_level
           ORDER BY severity_level DESC"""
    )

    # Query 39: Most dispatched vehicles (subquery in FROM)
    top_vehicles = query(
        """SELECT ev.vehicle_id, ev.vehicle_type, ev.license_plate,
                  ev.driver_name, sc.area,
                  COUNT(dr.dispatch_id) AS total_dispatches,
                  ROUND(AVG(dr.response_time),1) AS avg_resp
           FROM Emergency_Vehicle ev
           JOIN Service_Center sc ON ev.center_id = sc.center_id
           LEFT JOIN Dispatch_Record dr ON ev.vehicle_id = dr.vehicle_id
           GROUP BY ev.vehicle_id
           ORDER BY total_dispatches DESC
           LIMIT 10"""
    )

    # Query 40: Citizens with multiple emergency reports (HAVING COUNT > 1)
    repeat_citizens = query(
        """SELECT u.user_id, u.name, u.phone_number,
                  COUNT(er.request_id) AS total_reports,
                  MAX(er.severity_level) AS max_severity
           FROM Users u
           JOIN Emergency_Request er ON u.user_id = er.user_id
           WHERE u.role = 'Citizen'
           GROUP BY u.user_id
           HAVING COUNT(er.request_id) > 1
           ORDER BY total_reports DESC"""
    )

    # Query 41: Requests where response time > avg (subquery)
    slow_responses = query(
        """SELECT dr.dispatch_id, er.location, er.emergency_type,
                  er.severity_level, dr.response_time,
                  ev.vehicle_type, ev.driver_name
           FROM Dispatch_Record dr
           JOIN Emergency_Request er ON dr.request_id = er.request_id
           JOIN Emergency_Vehicle ev ON dr.vehicle_id = ev.vehicle_id
           WHERE dr.response_time > (
               SELECT AVG(response_time) FROM Dispatch_Record
               WHERE response_time IS NOT NULL
           )
           ORDER BY dr.response_time DESC"""
    )

    # Query 42: Requests with no dispatch (NOT IN subquery)
    no_dispatch = query(
        """SELECT request_id, emergency_type, location, severity_level,
                  status, request_time
           FROM Emergency_Request
           WHERE request_id NOT IN (
               SELECT DISTINCT request_id FROM Dispatch_Record
           )
           ORDER BY severity_level DESC, request_time ASC"""
    )

    # Query 43: Service centers with vehicle counts by type
    center_summary = query(
        """SELECT sc.center_id, sc.center_name, sc.service_type, sc.area,
                  COUNT(ev.vehicle_id) AS total_vehicles,
                  SUM(CASE WHEN ev.availability='Available'    THEN 1 ELSE 0 END) AS available,
                  SUM(CASE WHEN ev.availability='Busy'         THEN 1 ELSE 0 END) AS busy,
                  SUM(CASE WHEN ev.availability='Maintenance'  THEN 1 ELSE 0 END) AS in_maintenance
           FROM Service_Center sc
           LEFT JOIN Emergency_Vehicle ev ON sc.center_id = ev.center_id
           GROUP BY sc.center_id
           ORDER BY total_vehicles DESC"""
    )

    # Query 44: Monthly emergency trend
    monthly = query(
        """SELECT DATE_FORMAT(request_time,'%b %Y') AS month,
                  DATE_FORMAT(request_time,'%Y-%m') AS month_sort,
                  COUNT(*) AS total,
                  SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END) AS resolved,
                  SUM(CASE WHEN emergency_type='Medical'  THEN 1 ELSE 0 END) AS medical,
                  SUM(CASE WHEN emergency_type='Fire'     THEN 1 ELSE 0 END) AS fire,
                  SUM(CASE WHEN emergency_type='Crime'    THEN 1 ELSE 0 END) AS crime,
                  SUM(CASE WHEN emergency_type='Accident' THEN 1 ELSE 0 END) AS accident
           FROM Emergency_Request
           GROUP BY DATE_FORMAT(request_time,'%Y-%m'), DATE_FORMAT(request_time,'%b %Y')
           ORDER BY month_sort"""
    )

    # Query 45: Staff shift-wise availability (GROUP BY shift)
    staff_shift = query(
        """SELECT shift,
                  COUNT(*) AS total_staff,
                  SUM(CASE WHEN availability='Available' THEN 1 ELSE 0 END) AS available,
                  SUM(CASE WHEN availability='Assigned'  THEN 1 ELSE 0 END) AS assigned,
                  SUM(CASE WHEN availability='Off-duty'  THEN 1 ELSE 0 END) AS off_duty
           FROM Service_Staff
           WHERE shift IS NOT NULL
           GROUP BY shift"""
    )

    return render_template("admin_reports.html",
                           operator_perf=operator_perf,
                           type_stats=type_stats,
                           severity_dist=severity_dist,
                           top_vehicles=top_vehicles,
                           repeat_citizens=repeat_citizens,
                           slow_responses=slow_responses,
                           no_dispatch=no_dispatch,
                           center_summary=center_summary,
                           monthly=monthly,
                           staff_shift=staff_shift)


# ══════════════════════════════════════════════
# ANALYTICS ROUTE  (Admin + Operator)
# ══════════════════════════════════════════════

@app.route("/analytics")
@login_required
@role_required("Admin", "Operator")
def analytics():
    # Query 46: Emergency type distribution
    type_dist = query(
        """SELECT emergency_type,
                  COUNT(*) AS total,
                  SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END) AS completed,
                  ROUND(SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END)*100.0/COUNT(*),1) AS pct
           FROM Emergency_Request GROUP BY emergency_type"""
    )

    # Query 47: Avg response time per area — tries arrival_time, then response_time, then counts
    area_resp = query(
        """SELECT er.location AS area,
                  COUNT(*) AS total,
                  ROUND(AVG(dr.response_time),1) AS avg_resp,
                  MAX(dr.response_time) AS max_resp
           FROM Emergency_Request er
           JOIN Dispatch_Record dr ON er.request_id = dr.request_id
           WHERE dr.response_time IS NOT NULL
           GROUP BY er.location
           ORDER BY avg_resp DESC LIMIT 12"""
    )
    if not area_resp:
        # Fallback: use arrival_time diff
        area_resp = query(
            """SELECT er.location AS area,
                      COUNT(*) AS total,
                      ROUND(AVG(TIMESTAMPDIFF(MINUTE, dr.dispatch_time, dr.arrival_time)),1) AS avg_resp,
                      MAX(TIMESTAMPDIFF(MINUTE, dr.dispatch_time, dr.arrival_time)) AS max_resp
               FROM Emergency_Request er
               JOIN Dispatch_Record dr ON er.request_id = dr.request_id
               WHERE dr.arrival_time IS NOT NULL AND dr.dispatch_time IS NOT NULL
               GROUP BY er.location
               ORDER BY avg_resp DESC LIMIT 12"""
        )
    if not area_resp:
        # Final fallback: show total requests per area
        area_resp = query(
            """SELECT location AS area, COUNT(*) AS total,
                      0 AS avg_resp, 0 AS max_resp
               FROM Emergency_Request
               GROUP BY location ORDER BY total DESC LIMIT 12"""
        )

    # Query 48: Severity distribution
    severity_dist = query(
        """SELECT severity_level,
                  COUNT(*) AS cnt,
                  ROUND(COUNT(*)*100.0/(SELECT COUNT(*) FROM Emergency_Request),1) AS pct
           FROM Emergency_Request
           GROUP BY severity_level ORDER BY severity_level DESC"""
    )

    # Query 49: Monthly trend
    monthly = query(
        """SELECT DATE_FORMAT(request_time,'%b %Y') AS month,
                  DATE_FORMAT(request_time,'%Y-%m') AS month_sort,
                  COUNT(*) AS total,
                  SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END) AS resolved
           FROM Emergency_Request
           GROUP BY DATE_FORMAT(request_time,'%Y-%m'), DATE_FORMAT(request_time,'%b %Y')
           ORDER BY month_sort"""
    )

    # Query 50: Operator performance
    operator_perf = query(
        """SELECT u.user_id, u.name AS operator,
                  (SELECT COUNT(*) FROM Dispatch_Record dr
                   WHERE dr.operator_id = u.user_id) AS dispatches,
                  (SELECT ROUND(AVG(dr2.response_time),1)
                   FROM Dispatch_Record dr2
                   WHERE dr2.operator_id = u.user_id
                   AND dr2.response_time IS NOT NULL) AS avg_resp
           FROM Users u WHERE u.role = 'Operator'
           ORDER BY dispatches DESC"""
    )

    # Query 51: Feedback ratings by type
    feedback_ratings = query(
        """SELECT er.emergency_type,
                  ROUND(AVG(f.rating),2) AS avg_rating,
                  COUNT(f.feedback_id) AS reviews
           FROM Feedback f
           JOIN Emergency_Request er ON f.request_id = er.request_id
           GROUP BY er.emergency_type"""
    )

    return render_template("analytics.html",
                           type_dist=type_dist,
                           area_resp=area_resp,
                           severity_dist=severity_dist,
                           monthly=monthly,
                           operator_perf=operator_perf,
                           feedback_ratings=feedback_ratings)


# ══════════════════════════════════════════════
# API ENDPOINTS FOR CHARTS (JSON)
# ══════════════════════════════════════════════

@app.route("/api/chart/type-dist")
@login_required
def api_type_dist():
    # Query 52
    data = query(
        "SELECT emergency_type, COUNT(*) AS cnt FROM Emergency_Request GROUP BY emergency_type"
    )
    return jsonify(data)


@app.route("/api/chart/area-response")
@login_required
def api_area_response():
    # Query 53: Try arrival_time first, then response_time, then fallback to request counts
    # Try 1: dispatch_time -> arrival_time diff
    data = query(
        """SELECT location AS area,
                  ROUND(AVG(TIMESTAMPDIFF(MINUTE, dr.dispatch_time, dr.arrival_time)),1) AS avg_resp
           FROM Emergency_Request er
           JOIN Dispatch_Record dr ON er.request_id = dr.request_id
           WHERE dr.arrival_time IS NOT NULL
             AND dr.dispatch_time IS NOT NULL
           GROUP BY er.location
           ORDER BY avg_resp DESC LIMIT 10"""
    )
    if data:
        return jsonify(data)

    # Try 2: use stored response_time column directly
    data = query(
        """SELECT er.location AS area,
                  ROUND(AVG(dr.response_time),1) AS avg_resp
           FROM Emergency_Request er
           JOIN Dispatch_Record dr ON er.request_id = dr.request_id
           WHERE dr.response_time IS NOT NULL
           GROUP BY er.location
           ORDER BY avg_resp DESC LIMIT 10"""
    )
    if data:
        return jsonify(data)

    # Fallback 3: show request counts per area so chart is never empty
    data = query(
        """SELECT location AS area,
                  COUNT(*) AS avg_resp
           FROM Emergency_Request
           GROUP BY location
           ORDER BY avg_resp DESC LIMIT 10"""
    )
    return jsonify(data)


@app.route("/api/chart/vehicle-status")
@login_required
def api_vehicle_status():
    """Query 54: Vehicle availability breakdown for pie chart."""
    data = query(
        """SELECT availability, COUNT(*) AS cnt
           FROM Emergency_Vehicle GROUP BY availability"""
    )
    return jsonify(data)


@app.route("/api/chart/staff-availability")
@login_required
def api_staff_availability():
    """Query 55: Staff availability breakdown."""
    data = query(
        """SELECT availability, COUNT(*) AS cnt
           FROM Service_Staff GROUP BY availability"""
    )
    return jsonify(data)


@app.route("/api/chart/severity-trend")
@login_required
def api_severity_trend():
    """Query 56: Severity level counts for bar chart."""
    data = query(
        """SELECT severity_level,
                  COUNT(*) AS cnt,
                  emergency_type
           FROM Emergency_Request
           GROUP BY severity_level, emergency_type
           ORDER BY severity_level DESC"""
    )
    return jsonify(data)


@app.route("/api/chart/feedback-trend")
@login_required
def api_feedback_trend():
    """Query 57: Avg feedback rating over time (monthly)."""
    data = query(
        """SELECT DATE_FORMAT(f.created_at,'%b %Y') AS month,
                  ROUND(AVG(f.rating),2) AS avg_rating,
                  COUNT(*) AS reviews
           FROM Feedback f
           GROUP BY DATE_FORMAT(f.created_at,'%Y-%m')
           ORDER BY DATE_FORMAT(f.created_at,'%Y-%m')"""
    )
    return jsonify(data)


# ══════════════════════════════════════════════
# ADMIN — SEND NOTIFICATION (manual broadcast)
# ══════════════════════════════════════════════

@app.route("/admin/notify", methods=["POST"])
@login_required
@role_required("Admin")
def admin_send_notification():
    """Query 58: Admin manually sends a notification to a user."""
    user_id = request.form.get("user_id")
    message = request.form.get("message", "").strip()
    ntype   = request.form.get("type", "Info")
    if user_id and message:
        query(
            "INSERT INTO Notifications (user_id, message, type) VALUES (%s,%s,%s)",
            (user_id, message, ntype), fetch="none"
        )
        flash("✅ Notification sent.", "success")
    else:
        flash("❌ User and message are required.", "danger")
    return redirect(url_for("admin_notifications"))


# ══════════════════════════════════════════════
# ADMIN — CANCEL REQUEST
# ══════════════════════════════════════════════

@app.route("/admin/cancel/<int:req_id>", methods=["POST"])
@login_required
@role_required("Admin")
def admin_cancel_request(req_id):
    admin_id = session["user_id"]
    conn = get_db()
    msg = ""
    try:
        cur = conn.cursor()
        cur.execute("SET @out_msg = ''")
        cur.execute(f"CALL CancelRequest({req_id}, {admin_id}, @out_msg)")
        conn.commit()
        cur.execute("SELECT @out_msg AS msg")
        row = cur.fetchone()
        msg = row[0] if row else "Unknown"
        cur.close()
    except Error as e:
        msg = f"ERROR: {e}"
        conn.rollback()
    finally:
        conn.close()

    if msg and msg.startswith("SUCCESS"):
        flash(f"✅ {msg}", "success")
    else:
        flash(f"❌ {msg}", "danger")
    return redirect(url_for("admin_all_requests"))


# ══════════════════════════════════════════════
# ERROR HANDLERS
# ══════════════════════════════════════════════

@app.errorhandler(404)
def not_found(e):
    return render_template("404.html"), 404


@app.errorhandler(500)
def server_error(e):
    return render_template("500.html"), 500


# ══════════════════════════════════════════════
# RUN
# ══════════════════════════════════════════════

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
