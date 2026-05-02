/* ============================================================
   ERTS — Main JavaScript
   ============================================================ */

document.addEventListener('DOMContentLoaded', function () {

  // ── SIDEBAR TOGGLE ──
  const sidebar       = document.getElementById('sidebar');
  const sidebarToggle = document.getElementById('sidebarToggle');

  if (sidebarToggle && sidebar) {
    sidebarToggle.addEventListener('click', function () {
      if (window.innerWidth <= 992) {
        sidebar.classList.toggle('open');
      } else {
        sidebar.classList.toggle('collapsed');
        document.querySelector('.main-wrapper').style.marginLeft =
          sidebar.classList.contains('collapsed') ? '0' : 'var(--sidebar-w)';
      }
    });

    // Close sidebar on outside click (mobile)
    document.addEventListener('click', function (e) {
      if (window.innerWidth <= 992 &&
          sidebar.classList.contains('open') &&
          !sidebar.contains(e.target) &&
          !sidebarToggle.contains(e.target)) {
        sidebar.classList.remove('open');
      }
    });
  }

  // ── LIVE CLOCK ──
  const timeEl = document.getElementById('liveTime');
  if (timeEl) {
    function updateTime() {
      const now = new Date();
      const h = String(now.getHours()).padStart(2, '0');
      const m = String(now.getMinutes()).padStart(2, '0');
      const s = String(now.getSeconds()).padStart(2, '0');
      timeEl.textContent = `${h}:${m}:${s}`;
    }
    updateTime();
    setInterval(updateTime, 1000);
  }

  // ── AUTO-DISMISS FLASH ALERTS (after 5s) ──
  document.querySelectorAll('.flash-alert').forEach(function (alert) {
    setTimeout(function () {
      const bsAlert = bootstrap.Alert.getOrCreateInstance(alert);
      if (bsAlert) bsAlert.close();
    }, 5000);
  });

  // ── TABLE ROW HOVER — add cursor pointer ──
  document.querySelectorAll('.erts-table tbody tr').forEach(function (row) {
    row.style.cursor = 'default';
  });

  // ── ANIMATE KPI COUNTERS ──
  document.querySelectorAll('.kpi-value').forEach(function (el) {
    const text = el.textContent.trim();
    const num  = parseFloat(text.replace(/[^0-9.]/g, ''));
    if (isNaN(num) || num === 0) return;

    const suffix = text.replace(/[0-9.]/g, '').trim();
    const isDecimal = text.includes('.');
    const duration  = 800;
    const step      = 16;
    const steps     = Math.ceil(duration / step);
    let current     = 0;
    let count       = 0;

    const timer = setInterval(function () {
      count++;
      current = (num * count) / steps;
      if (count >= steps) {
        current = num;
        clearInterval(timer);
      }
      el.textContent = (isDecimal ? current.toFixed(1) : Math.floor(current)) + suffix;
    }, step);
  });

  // ── REPORT FORM — Prevent double submit ──
  const reportForm = document.getElementById('reportForm');
  if (reportForm) {
    reportForm.addEventListener('submit', function (e) {
      const btn = reportForm.querySelector('button[type="submit"]');
      if (btn) {
        btn.disabled = true;
        btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin me-2"></i>Submitting…';
        // Re-enable after 5s in case of error
        setTimeout(function () {
          btn.disabled = false;
          btn.innerHTML = '<i class="fa-solid fa-bell-concierge me-2"></i>Submit Emergency Report';
        }, 5000);
      }
    });
  }

  // ── TOOLTIPS (Bootstrap) ──
  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(function (el) {
    new bootstrap.Tooltip(el);
  });

  // ── SEVERITY LABEL HIGHLIGHT on select ──
  document.querySelectorAll('.sev-radio').forEach(function (radio) {
    radio.addEventListener('change', function () {
      document.querySelectorAll('.sev-label').forEach(l => l.style.transform = '');
      const lbl = document.querySelector('label[for="' + this.id + '"]');
      if (lbl) lbl.style.transform = 'scale(1.04)';
    });
  });

  // ── TYPE SELECTOR ANIMATION ──
  document.querySelectorAll('.type-radio').forEach(function (radio) {
    radio.addEventListener('change', function () {
      document.querySelectorAll('.type-label').forEach(l => l.style.transform = '');
      const lbl = document.querySelector('label[for="' + this.id + '"]');
      if (lbl) lbl.style.transform = 'scale(1.04)';
    });
  });

  // ── RESPONSIVE RESIZE HANDLER ──
  window.addEventListener('resize', function () {
    if (window.innerWidth > 992 && sidebar) {
      sidebar.classList.remove('open');
    }
  });

  // ── HIGHLIGHT ACTIVE TABLE ROWS ON CLICK ──
  document.querySelectorAll('.erts-table tbody tr').forEach(function (row) {
    row.addEventListener('click', function () {
      document.querySelectorAll('.erts-table tbody tr').forEach(r => r.classList.remove('selected-row'));
      this.classList.add('selected-row');
    });
  });

});
