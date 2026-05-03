-- ============================================================
--   EMERGENCY RESPONSE OPTIMIZATION AND TRACKING SYSTEM
--   Complete SQL + PL/SQL Implementation — 100 Records
--   Subject: DBMS (UCS310) | Thapar Institute of Engineering
--   Group - 2Q23
-- ============================================================

DROP DATABASE IF EXISTS Emergency_Service_DB;
CREATE DATABASE Emergency_Service_DB;
USE Emergency_Service_DB;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- SECTION 1: TABLE CREATION (DDL)
-- ============================================================

CREATE TABLE Users (
    user_id      INT AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15)  UNIQUE,
    email        VARCHAR(100) UNIQUE,
    password     VARCHAR(255) NOT NULL,
    role         ENUM('Citizen','Operator','Admin') NOT NULL DEFAULT 'Citizen',
    is_active    BOOLEAN      DEFAULT TRUE,
    created_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Service_Center (
    center_id      INT AUTO_INCREMENT PRIMARY KEY,
    center_name    VARCHAR(100) NOT NULL,
    service_type   ENUM('Ambulance','Police','Fire') NOT NULL,
    area           VARCHAR(100) NOT NULL,
    latitude       DECIMAL(10,6),
    longitude      DECIMAL(10,6),
    contact_number VARCHAR(15)
);

CREATE TABLE Emergency_Vehicle (
    vehicle_id        INT AUTO_INCREMENT PRIMARY KEY,
    center_id         INT,
    vehicle_type      ENUM('Ambulance','Police Van','Fire Truck') NOT NULL,
    license_plate     VARCHAR(20) UNIQUE,
    availability      ENUM('Available','Busy','Maintenance') DEFAULT 'Available',
    driver_name       VARCHAR(100),
    driver_phone      VARCHAR(15),
    current_latitude  DECIMAL(10,6),
    current_longitude DECIMAL(10,6),
    last_updated      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (center_id) REFERENCES Service_Center(center_id) ON DELETE SET NULL
);

CREATE TABLE Service_Staff (
    staff_id       INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(100) NOT NULL,
    role           ENUM('Driver','Paramedic','Firefighter','Police') NOT NULL,
    specialization VARCHAR(100),
    phone_number   VARCHAR(15) UNIQUE,
    availability   ENUM('Available','Assigned','Off-duty') DEFAULT 'Available',
    shift          ENUM('Morning','Evening','Night'),
    center_id      INT,
    FOREIGN KEY (center_id) REFERENCES Service_Center(center_id) ON DELETE SET NULL
);

CREATE TABLE Emergency_Request (
    request_id     INT AUTO_INCREMENT PRIMARY KEY,
    user_id        INT,
    emergency_type ENUM('Medical','Fire','Crime','Accident') NOT NULL,
    description    TEXT,
    location       VARCHAR(255) NOT NULL,
    latitude       DECIMAL(10,6),
    longitude      DECIMAL(10,6),
    severity_level INT CHECK (severity_level BETWEEN 1 AND 5),
    request_time   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status         ENUM('Pending','Assigned','In Progress','Completed','Cancelled') DEFAULT 'Pending',
    priority_score INT GENERATED ALWAYS AS (severity_level * 10) STORED,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE SET NULL
);

CREATE TABLE Caller_Details (
    caller_id          INT AUTO_INCREMENT PRIMARY KEY,
    request_id         INT NOT NULL,
    caller_name        VARCHAR(100),
    caller_phone       VARCHAR(15),
    relation_to_victim VARCHAR(50),
    FOREIGN KEY (request_id) REFERENCES Emergency_Request(request_id) ON DELETE CASCADE
);

CREATE TABLE Dispatch_Record (
    dispatch_id     INT AUTO_INCREMENT PRIMARY KEY,
    request_id      INT,
    vehicle_id      INT,
    operator_id     INT,
    dispatch_time   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    arrival_time    TIMESTAMP NULL,
    completion_time TIMESTAMP NULL,
    distance_km     DECIMAL(5,2),
    response_time   INT COMMENT 'Minutes from dispatch to arrival',
    status          ENUM('Assigned','In Progress','Completed') DEFAULT 'Assigned',
    FOREIGN KEY (request_id)  REFERENCES Emergency_Request(request_id) ON DELETE CASCADE,
    FOREIGN KEY (vehicle_id)  REFERENCES Emergency_Vehicle(vehicle_id) ON DELETE SET NULL,
    FOREIGN KEY (operator_id) REFERENCES Users(user_id)                ON DELETE SET NULL
);

CREATE TABLE Staff_Assignment (
    assignment_id     INT AUTO_INCREMENT PRIMARY KEY,
    staff_id          INT NOT NULL,
    request_id        INT NOT NULL,
    vehicle_id        INT,
    assigned_time     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    role_in_emergency ENUM('Driver','Responder','Support') NOT NULL,
    FOREIGN KEY (staff_id)   REFERENCES Service_Staff(staff_id)       ON DELETE CASCADE,
    FOREIGN KEY (request_id) REFERENCES Emergency_Request(request_id) ON DELETE CASCADE,
    FOREIGN KEY (vehicle_id) REFERENCES Emergency_Vehicle(vehicle_id) ON DELETE SET NULL
);

CREATE TABLE Incident_History (
    incident_id INT AUTO_INCREMENT PRIMARY KEY,
    request_id  INT,
    old_status  VARCHAR(50),
    new_status  VARCHAR(50),
    changed_by  INT,
    change_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    remarks     TEXT,
    FOREIGN KEY (request_id) REFERENCES Emergency_Request(request_id) ON DELETE CASCADE,
    FOREIGN KEY (changed_by) REFERENCES Users(user_id)                ON DELETE SET NULL
);

CREATE TABLE Vehicle_Maintenance (
    maintenance_id    INT AUTO_INCREMENT PRIMARY KEY,
    vehicle_id        INT,
    last_service_date DATE,
    next_service_date DATE,
    status            ENUM('OK','Needs Service','Under Maintenance') DEFAULT 'OK',
    remarks           TEXT,
    FOREIGN KEY (vehicle_id) REFERENCES Emergency_Vehicle(vehicle_id) ON DELETE CASCADE
);

CREATE TABLE Area_Response_Stats (
    area              VARCHAR(100) PRIMARY KEY,
    total_requests    INT          DEFAULT 0,
    avg_response_time DECIMAL(6,2) DEFAULT 0.00,
    max_response_time DECIMAL(6,2) DEFAULT 0.00,
    last_updated      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE Vehicle_Log (
    log_id     INT AUTO_INCREMENT PRIMARY KEY,
    vehicle_id INT,
    latitude   DECIMAL(10,6),
    longitude  DECIMAL(10,6),
    logged_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vehicle_id) REFERENCES Emergency_Vehicle(vehicle_id) ON DELETE CASCADE
);

CREATE TABLE Notifications (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT,
    message         TEXT NOT NULL,
    type            ENUM('Dispatch','Status Update','Alert','Info') DEFAULT 'Info',
    status          ENUM('Read','Unread') DEFAULT 'Unread',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);

CREATE TABLE Feedback (
    feedback_id INT AUTO_INCREMENT PRIMARY KEY,
    request_id  INT,
    user_id     INT,
    rating      INT CHECK (rating BETWEEN 1 AND 5),
    comments    TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (request_id) REFERENCES Emergency_Request(request_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)    REFERENCES Users(user_id)                ON DELETE CASCADE
);


-- ============================================================
-- SECTION 2: SAMPLE DATA — 100 RECORDS PER MAJOR TABLE
-- ============================================================

-- ------------------------------------------------------------
-- USERS: 5 Admin + 10 Operator + 85 Citizen = 100
-- ------------------------------------------------------------
INSERT INTO Users (name, phone_number, email, password, role) VALUES
-- Admins
('Arjun Mehta',      '9800000001', 'arjun@erts.com',     'admin@123', 'Admin'),
('Priya Singh',      '9800000002', 'priya@erts.com',     'admin@123', 'Admin'),
('Rahul Sharma',     '9800000003', 'rahul@erts.com',     'admin@123', 'Admin'),
('Sunita Kapoor',    '9800000004', 'sunita@erts.com',    'admin@123', 'Admin'),
('Vikram Malhotra',  '9800000005', 'vikram@erts.com',    'admin@123', 'Admin'),
-- Operators
('Neha Kapoor',      '9800000006', 'neha.op@erts.com',   'oper@123',  'Operator'),
('Manish Bose',      '9800000007', 'manish.op@erts.com', 'oper@123',  'Operator'),
('Anita Desai',      '9800000008', 'anita.op@erts.com',  'oper@123',  'Operator'),
('Suresh Pillai',    '9800000009', 'suresh.op@erts.com', 'oper@123',  'Operator'),
('Kavita Reddy',     '9800000010', 'kavita.op@erts.com', 'oper@123',  'Operator'),
('Deepak Jain',      '9800000011', 'deepak.op@erts.com', 'oper@123',  'Operator'),
('Rekha Iyer',       '9800000012', 'rekha.op@erts.com',  'oper@123',  'Operator'),
('Anil Gupta',       '9800000013', 'anil.op@erts.com',   'oper@123',  'Operator'),
('Shalini Nair',     '9800000014', 'shalini.op@erts.com','oper@123',  'Operator'),
('Rajesh Tiwari',    '9800000015', 'rajesh.op@erts.com', 'oper@123',  'Operator'),
-- Citizens (user_id 16 to 100)
('Suman Kaur',       '9900000001', 'suman@mail.com',     'cit@123', 'Citizen'),
('Rohit Verma',      '9900000002', 'rohit@mail.com',     'cit@123', 'Citizen'),
('Pooja Nair',       '9900000003', 'pooja@mail.com',     'cit@123', 'Citizen'),
('Meena Pillai',     '9900000004', 'meena@mail.com',     'cit@123', 'Citizen'),
('Aakash Gupta',     '9900000005', 'aakash@mail.com',    'cit@123', 'Citizen'),
('Simran Bhatia',    '9900000006', 'simran@mail.com',    'cit@123', 'Citizen'),
('Harpreet Gill',    '9900000007', 'harpreet@mail.com',  'cit@123', 'Citizen'),
('Naveen Chandra',   '9900000008', 'naveen@mail.com',    'cit@123', 'Citizen'),
('Asha Verma',       '9900000009', 'asha@mail.com',      'cit@123', 'Citizen'),
('Dinesh Pandey',    '9900000010', 'dinesh@mail.com',    'cit@123', 'Citizen'),
('Tanvir Ahmed',     '9900000011', 'tanvir@mail.com',    'cit@123', 'Citizen'),
('Geeta Sharma',     '9900000012', 'geeta@mail.com',     'cit@123', 'Citizen'),
('Ravi Kumar',       '9900000013', 'ravi@mail.com',      'cit@123', 'Citizen'),
('Lakshmi Devi',     '9900000014', 'lakshmi@mail.com',   'cit@123', 'Citizen'),
('Santosh Singh',    '9900000015', 'santosh@mail.com',   'cit@123', 'Citizen'),
('Farhan Qureshi',   '9900000016', 'farhan@mail.com',    'cit@123', 'Citizen'),
('Nisha Rawat',      '9900000017', 'nisha@mail.com',     'cit@123', 'Citizen'),
('Ajay Patel',       '9900000018', 'ajay@mail.com',      'cit@123', 'Citizen'),
('Kavya Menon',      '9900000019', 'kavya@mail.com',     'cit@123', 'Citizen'),
('Imran Khan',       '9900000020', 'imran@mail.com',     'cit@123', 'Citizen'),
('Sudha Rani',       '9900000021', 'sudha@mail.com',     'cit@123', 'Citizen'),
('Brijesh Yadav',    '9900000022', 'brijesh@mail.com',   'cit@123', 'Citizen'),
('Preethi Nair',     '9900000023', 'preethi@mail.com',   'cit@123', 'Citizen'),
('Kiran Bedi',       '9900000024', 'kiran@mail.com',     'cit@123', 'Citizen'),
('Mohit Sehgal',     '9900000025', 'mohit@mail.com',     'cit@123', 'Citizen'),
('Vandana Mishra',   '9900000026', 'vandana@mail.com',   'cit@123', 'Citizen'),
('Tarun Saxena',     '9900000027', 'tarun@mail.com',     'cit@123', 'Citizen'),
('Ritu Arora',       '9900000028', 'ritu@mail.com',      'cit@123', 'Citizen'),
('Gurpreet Sidhu',   '9900000029', 'gurpreet@mail.com',  'cit@123', 'Citizen'),
('Shikha Chauhan',   '9900000030', 'shikha@mail.com',    'cit@123', 'Citizen'),
('Abhishek Roy',     '9900000031', 'abhishek@mail.com',  'cit@123', 'Citizen'),
('Pallavi Joshi',    '9900000032', 'pallavi@mail.com',   'cit@123', 'Citizen'),
('Vivek Dubey',      '9900000033', 'vivek@mail.com',     'cit@123', 'Citizen'),
('Mansi Tripathi',   '9900000034', 'mansi@mail.com',     'cit@123', 'Citizen'),
('Ashok Kumar',      '9900000035', 'ashok@mail.com',     'cit@123', 'Citizen'),
('Deepa Nambiar',    '9900000036', 'deepa@mail.com',     'cit@123', 'Citizen'),
('Rajan Mehta',      '9900000037', 'rajan@mail.com',     'cit@123', 'Citizen'),
('Swati Rao',        '9900000038', 'swati@mail.com',     'cit@123', 'Citizen'),
('Piyush Agarwal',   '9900000039', 'piyush@mail.com',    'cit@123', 'Citizen'),
('Sarika Bose',      '9900000040', 'sarika@mail.com',    'cit@123', 'Citizen'),
('Hemant Tomar',     '9900000041', 'hemant@mail.com',    'cit@123', 'Citizen'),
('Divya Srivastava', '9900000042', 'divya@mail.com',     'cit@123', 'Citizen'),
('Nitesh Pandey',    '9900000043', 'nitesh@mail.com',    'cit@123', 'Citizen'),
('Ananya Das',       '9900000044', 'ananya@mail.com',    'cit@123', 'Citizen'),
('Manoj Shukla',     '9900000045', 'manoj@mail.com',     'cit@123', 'Citizen'),
('Priya Dutta',      '9900000046', 'priyad@mail.com',    'cit@123', 'Citizen'),
('Sahil Bansal',     '9900000047', 'sahil@mail.com',     'cit@123', 'Citizen'),
('Alka Singh',       '9900000048', 'alka@mail.com',      'cit@123', 'Citizen'),
('Vipin Yadav',      '9900000049', 'vipin@mail.com',     'cit@123', 'Citizen'),
('Komal Sethi',      '9900000050', 'komal@mail.com',     'cit@123', 'Citizen'),
('Rajiv Chawla',     '9900000051', 'rajiv@mail.com',     'cit@123', 'Citizen'),
('Nandini Pillai',   '9900000052', 'nandini@mail.com',   'cit@123', 'Citizen'),
('Sameer Kapoor',    '9900000053', 'sameer@mail.com',    'cit@123', 'Citizen'),
('Smita Ghosh',      '9900000054', 'smita@mail.com',     'cit@123', 'Citizen'),
('Yash Sharma',      '9900000055', 'yash@mail.com',      'cit@123', 'Citizen'),
('Lata Mishra',      '9900000056', 'lata@mail.com',      'cit@123', 'Citizen'),
('Deepak Rathi',     '9900000057', 'deepakr@mail.com',   'cit@123', 'Citizen'),
('Sunita Tiwari',    '9900000058', 'sunitaw@mail.com',   'cit@123', 'Citizen'),
('Gaurav Bhatt',     '9900000059', 'gaurav@mail.com',    'cit@123', 'Citizen'),
('Amrita Sinha',     '9900000060', 'amrita@mail.com',    'cit@123', 'Citizen'),
('Praveen Negi',     '9900000061', 'praveen@mail.com',   'cit@123', 'Citizen'),
('Savita Goel',      '9900000062', 'savita@mail.com',    'cit@123', 'Citizen'),
('Kunal Oberoi',     '9900000063', 'kunal@mail.com',     'cit@123', 'Citizen'),
('Shweta Tandon',    '9900000064', 'shweta@mail.com',    'cit@123', 'Citizen'),
('Naresh Pal',       '9900000065', 'naresh@mail.com',    'cit@123', 'Citizen'),
('Renuka Devi',      '9900000066', 'renuka@mail.com',    'cit@123', 'Citizen'),
('Sumit Bhardwaj',   '9900000067', 'sumit@mail.com',     'cit@123', 'Citizen'),
('Pushpa Kumari',    '9900000068', 'pushpa@mail.com',    'cit@123', 'Citizen'),
('Harish Chandra',   '9900000069', 'harish@mail.com',    'cit@123', 'Citizen'),
('Babita Singh',     '9900000070', 'babita@mail.com',    'cit@123', 'Citizen'),
('Lalit Kumar',      '9900000071', 'lalit@mail.com',     'cit@123', 'Citizen'),
('Manju Soni',       '9900000072', 'manju@mail.com',     'cit@123', 'Citizen'),
('Pankaj Thakur',    '9900000073', 'pankaj@mail.com',    'cit@123', 'Citizen'),
('Anita Yadav',      '9900000074', 'anitay@mail.com',    'cit@123', 'Citizen'),
('Shyam Sundar',     '9900000075', 'shyam@mail.com',     'cit@123', 'Citizen'),
('Shalini Kaur',     '9900000076', 'shalini@mail.com',   'cit@123', 'Citizen'),
('Umesh Joshi',      '9900000077', 'umesh@mail.com',     'cit@123', 'Citizen'),
('Pratima Roy',      '9900000078', 'pratima@mail.com',   'cit@123', 'Citizen'),
('Ramesh Verma',     '9900000079', 'rameshv@mail.com',   'cit@123', 'Citizen'),
('Susheela Batra',   '9900000080', 'susheela@mail.com',  'cit@123', 'Citizen'),
('Balvinder Singh',  '9900000081', 'balvinder@mail.com', 'cit@123', 'Citizen'),
('Champa Devi',      '9900000082', 'champa@mail.com',    'cit@123', 'Citizen'),
('Trilok Nath',      '9900000083', 'trilok@mail.com',    'cit@123', 'Citizen'),
('Amita Bajaj',      '9900000084', 'amita@mail.com',     'cit@123', 'Citizen'),
('Sunil Dhawan',     '9900000085', 'sunil@mail.com',     'cit@123', 'Citizen');

-- ------------------------------------------------------------
-- SERVICE CENTERS: 10 centers across city sectors
-- ------------------------------------------------------------
INSERT INTO Service_Center (center_name, service_type, area, latitude, longitude, contact_number) VALUES
('City Ambulance HQ',       'Ambulance', 'Sector 17', 30.7333, 76.7794, '0172-2610001'),
('East Ambulance Base',     'Ambulance', 'Sector 34', 30.7500, 76.8000, '0172-2610002'),
('North Ambulance Post',    'Ambulance', 'Sector 45', 30.7600, 76.7900, '0172-2610003'),
('North Police Station',    'Police',    'Sector 22', 30.7400, 76.7800, '0172-2620001'),
('South Police Post',       'Police',    'Sector 7',  30.7100, 76.7600, '0172-2620002'),
('West Police Outpost',     'Police',    'Sector 63', 30.7200, 76.7500, '0172-2620003'),
('Central Fire Brigade',    'Fire',      'Sector 11', 30.7250, 76.7700, '0172-2630001'),
('South Fire Station',      'Fire',      'Sector 19', 30.7150, 76.7650, '0172-2630002'),
('Industrial Fire Post',    'Fire',      'Sector 56', 30.7050, 76.7550, '0172-2630003'),
('Airport Ambulance Unit',  'Ambulance', 'Sector 9',  30.7080, 76.7480, '0172-2610004');

-- ------------------------------------------------------------
-- EMERGENCY VEHICLES: 30 vehicles (mix of types, statuses)
-- ------------------------------------------------------------
INSERT INTO Emergency_Vehicle (center_id, vehicle_type, license_plate, availability, driver_name, driver_phone) VALUES
(1,  'Ambulance',   'PB-10-AA-0001', 'Available',   'Gurpreet Singh',   '9111100001'),
(1,  'Ambulance',   'PB-10-AA-0002', 'Busy',        'Harjeet Kaur',     '9111100002'),
(1,  'Ambulance',   'PB-10-AA-0003', 'Available',   'Sandeep Bhatia',   '9111100003'),
(2,  'Ambulance',   'PB-10-AA-0004', 'Available',   'Kulwant Rana',     '9111100004'),
(2,  'Ambulance',   'PB-10-AA-0005', 'Maintenance', 'Dalbir Mann',      '9111100005'),
(3,  'Ambulance',   'PB-10-AA-0006', 'Available',   'Jaspreet Kaur',    '9111100006'),
(3,  'Ambulance',   'PB-10-AA-0007', 'Busy',        'Sukhwinder Gill',  '9111100007'),
(10, 'Ambulance',   'PB-10-AA-0008', 'Available',   'Rajinder Dhillon', '9111100008'),
(10, 'Ambulance',   'PB-10-AA-0009', 'Available',   'Parminder Brar',   '9111100009'),
(10, 'Ambulance',   'PB-10-AA-0010', 'Maintenance', 'Manjit Sandhu',    '9111100010'),
(4,  'Police Van',  'PB-10-BB-0001', 'Available',   'Rajinder Kumar',   '9111100011'),
(4,  'Police Van',  'PB-10-BB-0002', 'Busy',        'Sukhwinder Singh', '9111100012'),
(4,  'Police Van',  'PB-10-BB-0003', 'Available',   'Hardeep Bains',    '9111100013'),
(5,  'Police Van',  'PB-10-BB-0004', 'Available',   'Balwinder Sekhon', '9111100014'),
(5,  'Police Van',  'PB-10-BB-0005', 'Busy',        'Amarjit Grewal',   '9111100015'),
(5,  'Police Van',  'PB-10-BB-0006', 'Available',   'Gurmeet Toor',     '9111100016'),
(6,  'Police Van',  'PB-10-BB-0007', 'Available',   'Navdeep Sahi',     '9111100017'),
(6,  'Police Van',  'PB-10-BB-0008', 'Maintenance', 'Satnam Dhiman',    '9111100018'),
(6,  'Police Van',  'PB-10-BB-0009', 'Available',   'Lakhwinder Johal', '9111100019'),
(6,  'Police Van',  'PB-10-BB-0010', 'Available',   'Jagjit Cheema',    '9111100020'),
(7,  'Fire Truck',  'PB-10-CC-0001', 'Available',   'Manpreet Gill',    '9111100021'),
(7,  'Fire Truck',  'PB-10-CC-0002', 'Busy',        'Balvir Dhaliwal',  '9111100022'),
(7,  'Fire Truck',  'PB-10-CC-0003', 'Available',   'Surjit Sangha',    '9111100023'),
(8,  'Fire Truck',  'PB-10-CC-0004', 'Available',   'Gurmail Buttar',   '9111100024'),
(8,  'Fire Truck',  'PB-10-CC-0005', 'Maintenance', 'Harnam Brar',      '9111100025'),
(8,  'Fire Truck',  'PB-10-CC-0006', 'Available',   'Paramjit Uppal',   '9111100026'),
(9,  'Fire Truck',  'PB-10-CC-0007', 'Available',   'Avtar Sidhu',      '9111100027'),
(9,  'Fire Truck',  'PB-10-CC-0008', 'Busy',        'Tarlochan Rangi',  '9111100028'),
(9,  'Fire Truck',  'PB-10-CC-0009', 'Available',   'Nirmal Bhatia',    '9111100029'),
(9,  'Fire Truck',  'PB-10-CC-0010', 'Available',   'Ranjit Basra',     '9111100030');

-- ------------------------------------------------------------
-- SERVICE STAFF: 30 staff (drivers, paramedics, police, firefighters)
-- ------------------------------------------------------------
INSERT INTO Service_Staff (name, role, specialization, phone_number, availability, shift, center_id) VALUES
('Dr. Sanjay Patel',    'Paramedic',   'Trauma Care',         '9222200001', 'Available', 'Morning', 1),
('Dr. Rekha Menon',     'Paramedic',   'Cardiac Arrest',      '9222200002', 'Available', 'Evening', 1),
('Dr. Asha Rani',       'Paramedic',   'Pediatric Care',      '9222200003', 'Assigned',  'Morning', 2),
('Dr. Vijay Nair',      'Paramedic',   'Burns Treatment',     '9222200004', 'Available', 'Night',   2),
('Dr. Smita Joshi',     'Paramedic',   'Spinal Injury',       '9222200005', 'Available', 'Morning', 3),
('Dr. Ramesh Iyer',     'Paramedic',   'General Emergency',   '9222200006', 'Off-duty',  'Evening', 10),
('Dr. Kavita Shah',     'Paramedic',   'Obstetrics',          '9222200007', 'Available', 'Night',   10),
('Driver Ranjit',       'Driver',      'Emergency Driving',   '9222200008', 'Available', 'Morning', 1),
('Driver Suresh',       'Driver',      'Emergency Driving',   '9222200009', 'Assigned',  'Evening', 2),
('Driver Amarjit',      'Driver',      'Emergency Driving',   '9222200010', 'Available', 'Night',   3),
('Driver Gurmail',      'Driver',      'Emergency Driving',   '9222200011', 'Available', 'Morning', 10),
('Driver Jaswant',      'Driver',      'Emergency Driving',   '9222200012', 'Off-duty',  'Evening', 1),
('Constable Harish',    'Police',      'Criminal Arrest',     '9222200013', 'Available', 'Morning', 4),
('Inspector Kavita',    'Police',      'Investigation',       '9222200014', 'Assigned',  'Evening', 4),
('Constable Pradeep',   'Police',      'Traffic Control',     '9222200015', 'Available', 'Night',   5),
('SI Raminder Singh',   'Police',      'Narcotics',           '9222200016', 'Available', 'Morning', 5),
('Constable Anita',     'Police',      'Women Safety',        '9222200017', 'Off-duty',  'Evening', 6),
('ASI Balvinder',       'Police',      'Border Security',     '9222200018', 'Available', 'Night',   6),
('Inspector Gurdeep',   'Police',      'Cybercrime',          '9222200019', 'Available', 'Morning', 4),
('Constable Deepak',    'Police',      'Patrol',              '9222200020', 'Available', 'Evening', 5),
('Fireman Dalbir',      'Firefighter', 'High-Rise Rescue',    '9222200021', 'Available', 'Morning', 7),
('Fireman Jaswant',     'Firefighter', 'Chemical Fire',       '9222200022', 'Available', 'Evening', 7),
('Fireman Surjit',      'Firefighter', 'Forest Fire',         '9222200023', 'Assigned',  'Night',   7),
('Fireman Gurmail',     'Firefighter', 'Industrial Fire',     '9222200024', 'Available', 'Morning', 8),
('Fireman Harnam',      'Firefighter', 'Electrical Fire',     '9222200025', 'Available', 'Evening', 8),
('Fireman Ranjit',      'Firefighter', 'Residential Fire',    '9222200026', 'Off-duty',  'Night',   9),
('Fireman Avtar',       'Firefighter', 'Vehicle Fire',        '9222200027', 'Available', 'Morning', 9),
('Fireman Nirmal',      'Firefighter', 'Gas Leak Response',   '9222200028', 'Available', 'Evening', 9),
('Driver Paramjit',     'Driver',      'Heavy Vehicle',       '9222200029', 'Available', 'Night',   7),
('Driver Tarlochan',    'Driver',      'Emergency Driving',   '9222200030', 'Off-duty',  'Morning', 8);

-- ------------------------------------------------------------
-- EMERGENCY REQUESTS: 100 records with full variation
-- Mix of types, severities, statuses, locations, users
-- ------------------------------------------------------------
INSERT INTO Emergency_Request (user_id, emergency_type, description, location, latitude, longitude, severity_level, request_time, status) VALUES
(16, 'Medical',  'Person collapsed, unconscious on road',         'Sector 17, Near Park',        30.7340, 76.7800, 5, '2026-01-05 08:10:00', 'Completed'),
(17, 'Accident', 'Car collision, two injured',                    'Sector 22, Main Road',        30.7410, 76.7810, 4, '2026-01-05 09:30:00', 'Completed'),
(18, 'Fire',     'Kitchen fire spreading to upper floor',         'Sector 11, Block B',          30.7260, 76.7710, 5, '2026-01-05 10:15:00', 'Completed'),
(19, 'Crime',    'Robbery at gunpoint near market',               'Sector 7, Market Area',       30.7110, 76.7610, 4, '2026-01-05 11:00:00', 'Completed'),
(20, 'Medical',  'Child with severe allergic reaction',           'Sector 34, Flat 4C',          30.7510, 76.8010, 5, '2026-01-06 07:45:00', 'Completed'),
(21, 'Accident', 'Motorcycle skid, head injury',                  'Sector 22, Highway',          30.7420, 76.7820, 3, '2026-01-06 08:55:00', 'Completed'),
(22, 'Fire',     'Electrical fire in office building',            'Sector 17, IT Park',          30.7350, 76.7790, 4, '2026-01-06 09:30:00', 'Completed'),
(23, 'Crime',    'Chain snatching near ATM',                      'Sector 22, Bank Road',        30.7400, 76.7800, 2, '2026-01-06 10:20:00', 'Completed'),
(24, 'Medical',  'Old woman fell down stairs, fractured leg',     'Sector 45, Residential Colony',30.7600, 76.7900, 3, '2026-01-07 06:30:00', 'Completed'),
(25, 'Medical',  'Diabetic patient unconscious',                  'Sector 9, Near Airport',      30.7080, 76.7480, 4, '2026-01-07 07:00:00', 'Completed'),
(26, 'Fire',     'LPG cylinder blast in kitchen',                 'Sector 19, Block D',          30.7150, 76.7650, 5, '2026-01-07 07:30:00', 'Completed'),
(27, 'Crime',    'House break-in, valuables stolen',              'Sector 63, Green Avenue',     30.7200, 76.7500, 3, '2026-01-07 08:00:00', 'Completed'),
(28, 'Accident', 'Truck overturned on highway, oil spill',        'Sector 56, Industrial Road',  30.7050, 76.7550, 5, '2026-01-07 09:00:00', 'Completed'),
(29, 'Medical',  'Heart attack, patient unresponsive',            'Sector 17, Civil Lines',      30.7330, 76.7795, 5, '2026-01-08 10:00:00', 'Completed'),
(30, 'Crime',    'Domestic violence, woman injured',              'Sector 34, Lane 5',           30.7505, 76.8005, 4, '2026-01-08 10:30:00', 'Completed'),
(31, 'Accident', 'Bus collided with auto rickshaw',               'Sector 22, Roundabout',       30.7415, 76.7815, 4, '2026-01-08 11:00:00', 'Completed'),
(32, 'Fire',     'Short circuit fire in school lab',              'Sector 11, School Zone',      30.7255, 76.7705, 3, '2026-01-08 12:00:00', 'Completed'),
(33, 'Medical',  'Pregnant woman in labour, no transport',        'Sector 45, Anand Nagar',      30.7605, 76.7905, 5, '2026-01-09 05:00:00', 'Completed'),
(34, 'Crime',    'Drunk driving incident near bar',               'Sector 7, Night Street',      30.7105, 76.7605, 2, '2026-01-09 23:00:00', 'Completed'),
(35, 'Accident', 'Cyclist hit by car, unconscious',               'Sector 17, Park Lane',        30.7335, 76.7798, 4, '2026-01-10 07:15:00', 'Completed'),
(36, 'Medical',  'Snake bite, victim in pain',                    'Sector 9, Outer Road',        30.7082, 76.7482, 4, '2026-01-10 08:00:00', 'Completed'),
(37, 'Fire',     'Warehouse fire with toxic smoke',               'Sector 56, Warehouse Zone',   30.7052, 76.7552, 5, '2026-01-10 09:00:00', 'Completed'),
(38, 'Crime',    'Vehicle theft in parking lot',                  'Sector 63, Mall Parking',     30.7202, 76.7502, 2, '2026-01-10 10:30:00', 'Completed'),
(39, 'Medical',  'Asthma attack, no inhaler available',           'Sector 22, Colony A',         30.7412, 76.7812, 3, '2026-01-10 11:00:00', 'Completed'),
(40, 'Accident', 'Three vehicles pile-up on bridge',              'Sector 34, Bridge Point',     30.7512, 76.8012, 5, '2026-01-11 08:00:00', 'Completed'),
(41, 'Fire',     'Office paper fire out of control',              'Sector 17, Commerce Center',  30.7338, 76.7797, 3, '2026-01-11 09:30:00', 'Completed'),
(42, 'Crime',    'Assault at petrol station',                     'Sector 22, Petrol Pump',      30.7418, 76.7818, 3, '2026-01-11 10:00:00', 'Completed'),
(43, 'Medical',  'Elderly man with breathing difficulty',         'Sector 45, Old Age Home',     30.7608, 76.7908, 4, '2026-01-11 11:30:00', 'Completed'),
(44, 'Medical',  'Drowning in community pool',                    'Sector 7, Sports Complex',    30.7108, 76.7608, 5, '2026-01-12 14:00:00', 'Completed'),
(45, 'Fire',     'Restaurant grease fire',                        'Sector 19, Food Street',      30.7152, 76.7652, 4, '2026-01-12 19:00:00', 'Completed'),
(46, 'Crime',    'Cybercafe robbery at night',                    'Sector 9, Cyber Zone',        30.7085, 76.7485, 3, '2026-01-13 22:00:00', 'Completed'),
(47, 'Accident', 'Pedestrian hit by speeding car',                'Sector 11, School Road',      30.7258, 76.7708, 4, '2026-01-13 08:30:00', 'Completed'),
(48, 'Medical',  'Food poisoning, multiple victims',              'Sector 22, Dhaba Area',       30.7422, 76.7822, 4, '2026-01-13 13:00:00', 'Completed'),
(49, 'Fire',     'Forest edge fire near colony',                  'Sector 63, Green Belt',       30.7205, 76.7505, 4, '2026-01-14 15:00:00', 'Completed'),
(50, 'Crime',    'Kidnapping attempt near school',                'Sector 45, School Gate',      30.7610, 76.7910, 5, '2026-01-14 08:00:00', 'Completed'),
(51, 'Medical',  'Worker electrocuted at construction site',      'Sector 56, Construction Zone',30.7055, 76.7555, 5, '2026-01-15 10:00:00', 'Completed'),
(52, 'Accident', 'Train crossing mishap, vehicle stuck',          'Sector 34, Railway Crossing', 30.7515, 76.8015, 5, '2026-01-15 11:00:00', 'Completed'),
(53, 'Fire',     'AC unit explosion in apartment',                'Sector 17, Apartment Complex',30.7342, 76.7802, 4, '2026-01-15 14:00:00', 'Completed'),
(54, 'Crime',    'Theft from parked car',                         'Sector 7, Temple Road',       30.7112, 76.7612, 1, '2026-01-15 18:00:00', 'Completed'),
(55, 'Medical',  'Fever with seizures in a child',                'Sector 22, Sector C',         30.7425, 76.7825, 4, '2026-01-16 03:00:00', 'Completed'),
(56, 'Accident', 'Car fell into ditch, driver trapped',           'Sector 9, Ring Road',         30.7088, 76.7488, 5, '2026-01-16 20:00:00', 'Completed'),
(57, 'Fire',     'Festival fireworks caused roof fire',           'Sector 19, Residential',      30.7155, 76.7655, 3, '2026-01-16 21:00:00', 'Completed'),
(58, 'Crime',    'Drug peddling near college',                    'Sector 11, College Lane',     30.7262, 76.7712, 3, '2026-01-17 17:00:00', 'Completed'),
(59, 'Medical',  'Dog bite, stray dog attack',                    'Sector 45, Park Area',        30.7612, 76.7912, 2, '2026-01-17 09:00:00', 'Completed'),
(60, 'Accident', 'Child fell from school bus',                    'Sector 63, Highway',          30.7208, 76.7508, 3, '2026-01-17 07:30:00', 'Completed'),
(61, 'Fire',     'Gas pipeline leak causing fire',                'Sector 56, Industrial Area',  30.7058, 76.7558, 5, '2026-01-18 06:00:00', 'Completed'),
(62, 'Crime',    'Suicide attempt — person threatening',          'Sector 34, Rooftop',          30.7518, 76.8018, 5, '2026-01-18 12:00:00', 'Completed'),
(63, 'Medical',  'Stroke — patient cannot speak or move',         'Sector 17, Sector D',         30.7345, 76.7805, 5, '2026-01-18 15:00:00', 'Completed'),
(64, 'Accident', 'Head-on collision on expressway',               'Sector 22, Expressway',       30.7428, 76.7828, 5, '2026-01-19 06:30:00', 'Completed'),
(65, 'Fire',     'Chemical storage area fire',                    'Sector 9, Chemical Plant',    30.7092, 76.7492, 5, '2026-01-19 08:00:00', 'Completed'),
(66, 'Crime',    'Harassment reported by woman late night',       'Sector 7, Bus Stand',         30.7115, 76.7615, 3, '2026-01-19 22:30:00', 'Completed'),
-- Next 50 — mix of statuses including Pending/Assigned/In Progress
(67, 'Medical',  'Old man fell from bed, hip fracture',           'Sector 45, Block C',          30.7615, 76.7915, 3, '2026-01-20 07:00:00', 'Completed'),
(68, 'Accident', 'Truck overloaded, brakes failed',               'Sector 56, Truck Zone',       30.7062, 76.7562, 4, '2026-01-20 09:00:00', 'Completed'),
(69, 'Fire',     'Transformer blast on street',                   'Sector 19, Main Chowk',       30.7158, 76.7658, 4, '2026-01-20 11:00:00', 'Completed'),
(70, 'Crime',    'Pickpocket at railway station',                 'Sector 63, Railway Stn',      30.7212, 76.7512, 2, '2026-01-20 13:00:00', 'Completed'),
(71, 'Medical',  'Unconscious adult, alcohol poisoning',          'Sector 11, Near Bar',         30.7265, 76.7715, 4, '2026-01-21 01:00:00', 'Completed'),
(72, 'Accident', 'Bicycle hit by auto, kid injured',              'Sector 34, School Lane',      30.7522, 76.8022, 3, '2026-01-21 08:15:00', 'Completed'),
(73, 'Fire',     'Clothes shop fire due to heater',               'Sector 17, Market',           30.7348, 76.7808, 3, '2026-01-21 10:30:00', 'Completed'),
(74, 'Crime',    'ATM skimming device found, suspicious',         'Sector 22, ATM Kiosk',        30.7432, 76.7832, 2, '2026-01-21 14:00:00', 'Completed'),
(75, 'Medical',  'Serious burn injury from cooking',              'Sector 9, Flat 2B',           30.7095, 76.7495, 4, '2026-01-22 12:30:00', 'Completed'),
(76, 'Accident', 'Speeding car hit street vendor',                'Sector 7, Sabzi Mandi',       30.7118, 76.7618, 4, '2026-01-22 08:45:00', 'Completed'),
(77, 'Fire',     'Slum area fire, multiple huts burning',         'Sector 63, JJ Colony',        30.7218, 76.7518, 5, '2026-01-22 14:00:00', 'In Progress'),
(78, 'Crime',    'Riots near religious site',                     'Sector 56, Temple Area',      30.7065, 76.7565, 5, '2026-01-22 16:00:00', 'In Progress'),
(79, 'Medical',  'Pregnant woman fell, bleeding',                 'Sector 45, Maternity Home',   30.7618, 76.7918, 5, '2026-01-23 04:00:00', 'In Progress'),
(80, 'Accident', 'Bridge under construction collapsed',           'Sector 19, Bridge Site',      30.7162, 76.7662, 5, '2026-01-23 10:00:00', 'In Progress'),
(81, 'Fire',     'Fire in hospital storeroom',                    'Sector 11, Civil Hospital',   30.7268, 76.7718, 5, '2026-01-23 11:00:00', 'In Progress'),
(82, 'Crime',    'Bomb threat call received at mall',             'Sector 17, Central Mall',     30.7352, 76.7812, 5, '2026-01-23 13:00:00', 'Assigned'),
(83, 'Medical',  'Multiple injured in factory blast',             'Sector 56, Factory Area',     30.7068, 76.7568, 5, '2026-01-24 09:00:00', 'Assigned'),
(84, 'Accident', 'Oil tanker overturned, road blocked',           'Sector 34, Highway',          30.7525, 76.8025, 4, '2026-01-24 10:00:00', 'Assigned'),
(85, 'Medical',  'Man having chest pain on treadmill',            'Sector 22, Gym Complex',      30.7435, 76.7835, 4, '2026-01-24 07:00:00', 'Assigned'),
(86, 'Fire',     'Petrol pump fire, spreading fast',              'Sector 9, NH-22',             30.7098, 76.7498, 5, '2026-01-25 08:30:00', 'Assigned'),
(87, 'Crime',    'Woman stalked and threatened in market',        'Sector 7, Sector Market',     30.7122, 76.7622, 3, '2026-01-25 19:00:00', 'Pending'),
(88, 'Medical',  'Child with head injury after fall',             'Sector 45, Play Area',        30.7622, 76.7922, 3, '2026-01-25 16:00:00', 'Pending'),
(89, 'Accident', 'Scooter vs tempo collision',                    'Sector 63, Local Road',       30.7222, 76.7522, 3, '2026-01-25 17:30:00', 'Pending'),
(90, 'Fire',     'Short circuit in ATM booth',                    'Sector 19, Commercial Area',  30.7165, 76.7665, 2, '2026-01-26 09:00:00', 'Pending'),
(91, 'Crime',    'Mobile phone snatched while jogging',           'Sector 11, Jogging Track',    30.7272, 76.7722, 2, '2026-01-26 06:30:00', 'Pending'),
(92, 'Medical',  'Severe migraine, patient disoriented',          'Sector 34, Apartment Block',  30.7528, 76.8028, 2, '2026-01-26 10:00:00', 'Pending'),
(93, 'Accident', 'Elderly person hit by e-rickshaw',              'Sector 17, Vegetable Market', 30.7355, 76.7815, 3, '2026-01-26 11:30:00', 'Pending'),
(94, 'Fire',     'Burning garbage near residential area',         'Sector 22, Garbage Dump',     30.7438, 76.7838, 2, '2026-01-27 14:00:00', 'Pending'),
(95, 'Crime',    'Fake currency detected at shop',                'Sector 9, Kiryana Store',     30.7102, 76.7502, 1, '2026-01-27 11:00:00', 'Pending'),
(96, 'Medical',  'Worker injured by machinery at factory',        'Sector 56, Factory B',        30.7072, 76.7572, 4, '2026-01-27 09:30:00', 'Pending'),
(97, 'Accident', 'Pothole caused tyre burst, car overturned',     'Sector 7, Ring Road',         30.7125, 76.7625, 4, '2026-01-28 08:00:00', 'Pending'),
(98, 'Fire',     'Wedding tent caught fire from firecracker',     'Sector 45, Marriage Palace',  30.7625, 76.7925, 4, '2026-01-28 21:00:00', 'Pending'),
(99, 'Crime',    'Online fraud — victim threatened',              'Sector 63, Reported Online',  30.7225, 76.7525, 2, '2026-01-29 10:00:00', 'Pending'),
(100,'Medical',  'Severe acid burn on hand and face',             'Sector 19, Factory Gate',     30.7168, 76.7668, 5, '2026-01-29 12:00:00', 'Pending');

-- ------------------------------------------------------------
-- CALLER DETAILS: 20 records (for requests where caller ≠ victim)
-- ------------------------------------------------------------
INSERT INTO Caller_Details (request_id, caller_name, caller_phone, relation_to_victim) VALUES
(1,  'Ramesh Sharma',     '9333300001', 'Bystander'),
(2,  'Sunita Patel',      '9333300002', 'Family Member'),
(5,  'Anita Bajaj',       '9333300003', 'Neighbour'),
(9,  'Dr. Prakash',       '9333300004', 'Doctor on Scene'),
(13, 'Truck Helper',      '9333300005', 'Co-worker'),
(18, 'Society Guard',     '9333300006', 'Security Staff'),
(20, 'School Principal',  '9333300007', 'School Official'),
(25, 'Passerby Citizen',  '9333300008', 'Bystander'),
(30, 'NGO Volunteer',     '9333300009', 'NGO Worker'),
(33, 'ASHA Worker',       '9333300010', 'Health Worker'),
(40, 'Traffic Police',    '9333300011', 'Official'),
(44, 'Pool Lifeguard',    '9333300012', 'Lifeguard'),
(48, 'Restaurant Staff',  '9333300013', 'Staff'),
(51, 'Site Supervisor',   '9333300014', 'Co-worker'),
(52, 'Railway Guard',     '9333300015', 'Railway Official'),
(62, 'RWA Secretary',     '9333300016', 'Neighbour'),
(64, 'Highway Patroller', '9333300017', 'Traffic Authority'),
(77, 'NGO Firefighter',   '9333300018', 'Volunteer'),
(79, 'Midwife',           '9333300019', 'Health Worker'),
(83, 'Factory Manager',   '9333300020', 'Management');

-- ------------------------------------------------------------
-- DISPATCH RECORDS: 70 records (for requests 1–76 that are Completed/InProgress)
-- (Requests 77-100 — some assigned, some pending — subset dispatched)
-- ------------------------------------------------------------
INSERT INTO Dispatch_Record (request_id, vehicle_id, operator_id, dispatch_time, arrival_time, completion_time, distance_km, response_time, status) VALUES
(1,  1,  6,  '2026-01-05 08:12:00', '2026-01-05 08:20:00', '2026-01-05 09:10:00', 2.5,  8,  'Completed'),
(2,  11, 7,  '2026-01-05 09:33:00', '2026-01-05 09:46:00', '2026-01-05 10:30:00', 3.1,  13, 'Completed'),
(3,  21, 6,  '2026-01-05 10:17:00', '2026-01-05 10:25:00', '2026-01-05 11:40:00', 1.8,  8,  'Completed'),
(4,  14, 8,  '2026-01-05 11:03:00', '2026-01-05 11:10:00', '2026-01-05 11:55:00', 2.0,  7,  'Completed'),
(5,  4,  6,  '2026-01-06 07:48:00', '2026-01-06 07:57:00', '2026-01-06 08:50:00', 2.2,  9,  'Completed'),
(6,  11, 9,  '2026-01-06 08:58:00', '2026-01-06 09:09:00', '2026-01-06 09:45:00', 3.0,  11, 'Completed'),
(7,  21, 6,  '2026-01-06 09:33:00', '2026-01-06 09:40:00', '2026-01-06 10:50:00', 1.5,  7,  'Completed'),
(8,  12, 7,  '2026-01-06 10:23:00', '2026-01-06 10:29:00', '2026-01-06 11:00:00', 1.2,  6,  'Completed'),
(9,  6,  8,  '2026-01-07 06:33:00', '2026-01-07 06:42:00', '2026-01-07 07:30:00', 2.8,  9,  'Completed'),
(10, 8,  10, '2026-01-07 07:03:00', '2026-01-07 07:11:00', '2026-01-07 08:00:00', 1.6,  8,  'Completed'),
(11, 24, 6,  '2026-01-07 07:33:00', '2026-01-07 07:39:00', '2026-01-07 09:00:00', 1.4,  6,  'Completed'),
(12, 17, 9,  '2026-01-07 08:04:00', '2026-01-07 08:18:00', '2026-01-07 09:15:00', 3.5,  14, 'Completed'),
(13, 27, 8,  '2026-01-07 09:03:00', '2026-01-07 09:12:00', '2026-01-07 11:30:00', 2.9,  9,  'Completed'),
(14, 1,  6,  '2026-01-08 10:03:00', '2026-01-08 10:11:00', '2026-01-08 11:30:00', 2.4,  8,  'Completed'),
(15, 14, 7,  '2026-01-08 10:33:00', '2026-01-08 10:41:00', '2026-01-08 11:45:00', 2.1,  8,  'Completed'),
(16, 13, 8,  '2026-01-08 11:04:00', '2026-01-08 11:16:00', '2026-01-08 12:30:00', 3.2,  12, 'Completed'),
(17, 22, 9,  '2026-01-08 12:03:00', '2026-01-08 12:11:00', '2026-01-08 13:10:00', 1.9,  8,  'Completed'),
(18, 3,  10, '2026-01-09 05:04:00', '2026-01-09 05:11:00', '2026-01-09 06:00:00', 2.6,  7,  'Completed'),
(19, 16, 6,  '2026-01-09 23:04:00', '2026-01-09 23:11:00', '2026-01-09 23:50:00', 2.0,  7,  'Completed'),
(20, 11, 7,  '2026-01-10 07:18:00', '2026-01-10 07:30:00', '2026-01-10 08:15:00', 3.0,  12, 'Completed'),
(21, 8,  8,  '2026-01-10 08:04:00', '2026-01-10 08:13:00', '2026-01-10 09:00:00', 2.2,  9,  'Completed'),
(22, 28, 9,  '2026-01-10 09:04:00', '2026-01-10 09:12:00', '2026-01-10 10:30:00', 1.8,  8,  'Completed'),
(23, 20, 10, '2026-01-10 10:34:00', '2026-01-10 10:39:00', '2026-01-10 11:20:00', 1.1,  5,  'Completed'),
(24, 3,  6,  '2026-01-10 11:04:00', '2026-01-10 11:14:00', '2026-01-10 12:00:00', 2.5,  10, 'Completed'),
(25, 22, 7,  '2026-01-11 08:05:00', '2026-01-11 08:14:00', '2026-01-11 09:30:00', 2.2,  9,  'Completed'),
(26, 21, 8,  '2026-01-11 09:34:00', '2026-01-11 09:42:00', '2026-01-11 11:00:00', 1.7,  8,  'Completed'),
(27, 14, 9,  '2026-01-11 10:04:00', '2026-01-11 10:16:00', '2026-01-11 11:00:00', 3.1,  12, 'Completed'),
(28, 4,  10, '2026-01-11 11:34:00', '2026-01-11 11:41:00', '2026-01-11 13:30:00', 2.3,  7,  'Completed'),
(29, 25, 6,  '2026-01-12 14:04:00', '2026-01-12 14:11:00', '2026-01-12 15:30:00', 1.5,  7,  'Completed'),
(30, 24, 7,  '2026-01-12 19:04:00', '2026-01-12 19:13:00', '2026-01-12 20:00:00', 2.1,  9,  'Completed'),
(31, 16, 8,  '2026-01-13 22:04:00', '2026-01-13 22:11:00', '2026-01-13 22:55:00', 1.8,  7,  'Completed'),
(32, 11, 9,  '2026-01-13 08:33:00', '2026-01-13 08:46:00', '2026-01-13 09:30:00', 3.2,  13, 'Completed'),
(33, 3,  10, '2026-01-13 13:04:00', '2026-01-13 13:12:00', '2026-01-13 14:30:00', 2.0,  8,  'Completed'),
(34, 23, 6,  '2026-01-14 15:04:00', '2026-01-14 15:11:00', '2026-01-14 17:00:00', 1.6,  7,  'Completed'),
(35, 19, 7,  '2026-01-14 08:04:00', '2026-01-14 08:16:00', '2026-01-14 09:00:00', 3.0,  12, 'Completed'),
(36, 1,  8,  '2026-01-15 10:04:00', '2026-01-15 10:13:00', '2026-01-15 11:30:00', 2.5,  9,  'Completed'),
(37, 13, 9,  '2026-01-15 11:04:00', '2026-01-15 11:12:00', '2026-01-15 12:45:00', 2.0,  8,  'Completed'),
(38, 21, 10, '2026-01-15 14:04:00', '2026-01-15 14:10:00', '2026-01-15 15:30:00', 1.4,  6,  'Completed'),
(39, 17, 6,  '2026-01-15 18:04:00', '2026-01-15 18:09:00', '2026-01-15 18:40:00', 1.1,  5,  'Completed'),
(40, 4,  7,  '2026-01-16 03:04:00', '2026-01-16 03:11:00', '2026-01-16 04:00:00', 2.3,  7,  'Completed'),
(41, 8,  8,  '2026-01-16 20:04:00', '2026-01-16 20:18:00', '2026-01-16 21:30:00', 3.4,  14, 'Completed'),
(42, 25, 9,  '2026-01-16 21:04:00', '2026-01-16 21:12:00', '2026-01-16 22:30:00', 2.0,  8,  'Completed'),
(43, 14, 10, '2026-01-17 17:04:00', '2026-01-17 17:14:00', '2026-01-17 18:00:00', 2.5,  10, 'Completed'),
(44, 6,  6,  '2026-01-17 09:04:00', '2026-01-17 09:12:00', '2026-01-17 10:00:00', 2.0,  8,  'Completed'),
(45, 11, 7,  '2026-01-17 07:33:00', '2026-01-17 07:43:00', '2026-01-17 08:30:00', 2.5,  10, 'Completed'),
(46, 28, 8,  '2026-01-18 06:04:00', '2026-01-18 06:11:00', '2026-01-18 07:30:00', 1.7,  7,  'Completed'),
(47, 19, 9,  '2026-01-18 12:04:00', '2026-01-18 12:14:00', '2026-01-18 13:30:00', 2.5,  10, 'Completed'),
(48, 1,  10, '2026-01-18 15:04:00', '2026-01-18 15:12:00', '2026-01-18 16:30:00', 2.0,  8,  'Completed'),
(49, 13, 6,  '2026-01-19 06:33:00', '2026-01-19 06:41:00', '2026-01-19 08:00:00', 2.0,  8,  'Completed'),
(50, 22, 7,  '2026-01-19 08:04:00', '2026-01-19 08:13:00', '2026-01-19 09:30:00', 2.2,  9,  'Completed'),
(51, 27, 8,  '2026-01-20 07:04:00', '2026-01-20 07:11:00', '2026-01-20 08:30:00', 1.7,  7,  'Completed'),
(52, 11, 9,  '2026-01-20 09:04:00', '2026-01-20 09:18:00', '2026-01-20 10:30:00', 3.5,  14, 'Completed'),
(53, 24, 10, '2026-01-20 11:04:00', '2026-01-20 11:11:00', '2026-01-20 12:30:00', 1.8,  7,  'Completed'),
(54, 16, 6,  '2026-01-20 13:04:00', '2026-01-20 13:09:00', '2026-01-20 13:45:00', 1.1,  5,  'Completed'),
(55, 1,  7,  '2026-01-21 01:04:00', '2026-01-21 01:11:00', '2026-01-21 02:00:00', 1.8,  7,  'Completed'),
(56, 13, 8,  '2026-01-21 08:18:00', '2026-01-21 08:29:00', '2026-01-21 09:00:00', 2.7,  11, 'Completed'),
(57, 21, 9,  '2026-01-21 10:33:00', '2026-01-21 10:40:00', '2026-01-21 11:45:00', 1.7,  7,  'Completed'),
(58, 17, 10, '2026-01-21 14:04:00', '2026-01-21 14:09:00', '2026-01-21 14:50:00', 1.1,  5,  'Completed'),
(59, 4,  6,  '2026-01-22 12:33:00', '2026-01-22 12:41:00', '2026-01-22 13:30:00', 2.0,  8,  'Completed'),
(60, 14, 7,  '2026-01-22 08:48:00', '2026-01-22 08:57:00', '2026-01-22 09:30:00', 2.2,  9,  'Completed'),
(61, 11, 8,  '2026-01-22 12:33:00', '2026-01-22 12:41:00', '2026-01-22 14:00:00', 2.0,  8,  'Completed'),
(62, 6,  9,  '2026-01-23 04:04:00', '2026-01-23 04:12:00', '2026-01-23 05:00:00', 2.0,  8,  'Completed'),
(63, 1,  10, '2026-01-23 10:04:00', '2026-01-23 10:22:00', '2026-01-23 12:30:00', 4.5,  18, 'Completed'),
(64, 27, 6,  '2026-01-23 11:04:00', '2026-01-23 11:12:00', '2026-01-23 13:30:00', 2.0,  8,  'Completed'),
(65, 21, 7,  '2026-01-23 13:04:00', '2026-01-23 13:13:00', '2026-01-23 15:00:00', 2.2,  9,  'Completed'),
(66, 19, 8,  '2026-01-24 06:33:00', '2026-01-24 06:44:00', '2026-01-24 08:00:00', 2.8,  11, 'Completed'),
(67, 8,  9,  '2026-01-24 09:04:00', '2026-01-24 09:13:00', '2026-01-24 10:30:00', 2.3,  9,  'Completed'),
(68, 22, 10, '2026-01-24 11:04:00', '2026-01-24 11:12:00', '2026-01-24 12:30:00', 2.0,  8,  'Completed'),
(69, 16, 6,  '2026-01-25 08:48:00', '2026-01-25 08:55:00', '2026-01-25 09:30:00', 1.8,  7,  'Completed'),
(70, 3,  7,  '2026-01-25 08:34:00', '2026-01-25 08:41:00', '2026-01-25 09:30:00', 1.7,  7,  'Completed'),
-- Assigned/In Progress dispatches
(77, 22, 8,  '2026-01-22 14:05:00', '2026-01-22 14:12:00', NULL,                  1.8,  7,  'In Progress'),
(78, 14, 9,  '2026-01-22 16:05:00', '2026-01-22 16:13:00', NULL,                  2.1,  8,  'In Progress'),
(79, 4,  6,  '2026-01-23 04:05:00', '2026-01-23 04:12:00', NULL,                  1.7,  7,  'In Progress'),
(80, 27, 10, '2026-01-23 10:05:00', '2026-01-23 10:18:00', NULL,                  3.2,  13, 'In Progress'),
(81, 21, 7,  '2026-01-23 11:05:00', '2026-01-23 11:12:00', NULL,                  1.8,  7,  'In Progress'),
(82, 11, 8,  '2026-01-23 13:05:00', NULL,                  NULL,                  2.5,  NULL,'Assigned'),
(83, 1,  9,  '2026-01-24 09:05:00', NULL,                  NULL,                  3.0,  NULL,'Assigned'),
(84, 13, 10, '2026-01-24 10:05:00', NULL,                  NULL,                  2.2,  NULL,'Assigned'),
(85, 3,  6,  '2026-01-24 07:05:00', NULL,                  NULL,                  1.9,  NULL,'Assigned'),
(86, 24, 7,  '2026-01-25 08:35:00', NULL,                  NULL,                  2.8,  NULL,'Assigned');

-- ------------------------------------------------------------
-- STAFF ASSIGNMENTS: 100 records
-- ------------------------------------------------------------
INSERT INTO Staff_Assignment (staff_id, request_id, vehicle_id, role_in_emergency) VALUES
(8,  1,  1,  'Driver'),   (1,  1,  1,  'Responder'),
(9,  2,  11, 'Driver'),   (13, 2,  11, 'Responder'),
(21, 3,  21, 'Responder'),(29, 3,  21, 'Driver'),
(8,  4,  14, 'Driver'),   (13, 4,  14, 'Responder'),
(11, 5,  4,  'Driver'),   (2,  5,  4,  'Responder'),
(9,  6,  11, 'Driver'),   (15, 6,  11, 'Responder'),
(29, 7,  21, 'Driver'),   (22, 7,  21, 'Responder'),
(10, 8,  12, 'Driver'),   (14, 8,  12, 'Responder'),
(11, 9,  6,  'Driver'),   (2,  9,  6,  'Responder'),
(8,  10, 8,  'Driver'),   (7,  10, 8,  'Responder'),
(21, 11, 24, 'Responder'),(25, 11, 24, 'Support'),
(18, 12, 17, 'Responder'),(20, 12, 17, 'Support'),
(27, 13, 27, 'Responder'),(29, 13, 27, 'Driver'),
(8,  14, 1,  'Driver'),   (1,  14, 1,  'Responder'),
(10, 15, 14, 'Driver'),   (16, 15, 14, 'Responder'),
(9,  16, 13, 'Driver'),   (13, 16, 13, 'Responder'),
(22, 17, 22, 'Responder'),(29, 17, 22, 'Driver'),
(11, 18, 3,  'Driver'),   (3,  18, 3,  'Responder'),
(10, 19, 16, 'Driver'),   (15, 19, 16, 'Responder'),
(8,  20, 11, 'Driver'),   (4,  20, 11, 'Responder'),
(9,  21, 8,  'Driver'),   (7,  21, 8,  'Responder'),
(28, 22, 28, 'Responder'),(30, 22, 28, 'Driver'),
(18, 23, 20, 'Responder'),(20, 23, 20, 'Support'),
(11, 24, 3,  'Driver'),   (5,  24, 3,  'Responder'),
(23, 25, 22, 'Responder'),(29, 25, 22, 'Driver'),
(21, 26, 21, 'Responder'),(25, 26, 21, 'Support'),
(10, 27, 14, 'Driver'),   (16, 27, 14, 'Responder'),
(8,  28, 4,  'Driver'),   (4,  28, 4,  'Responder'),
(24, 29, 25, 'Responder'),(29, 29, 25, 'Driver'),
(22, 30, 24, 'Responder'),(30, 30, 24, 'Driver'),
(9,  31, 16, 'Driver'),   (15, 31, 16, 'Responder'),
(8,  32, 11, 'Driver'),   (2,  32, 11, 'Responder'),
(11, 33, 3,  'Driver'),   (1,  33, 3,  'Responder'),
(26, 34, 23, 'Responder'),(29, 34, 23, 'Driver'),
(17, 35, 19, 'Responder'),(20, 35, 19, 'Support'),
(8,  36, 1,  'Driver'),   (3,  36, 1,  'Responder'),
(10, 37, 13, 'Driver'),   (13, 37, 13, 'Responder'),
(21, 38, 21, 'Responder'),(25, 38, 21, 'Support'),
(9,  39, 17, 'Driver'),   (15, 39, 17, 'Responder'),
(8,  40, 4,  'Driver'),   (4,  40, 4,  'Responder'),
(9,  77, 22, 'Driver'),   (23, 77, 22, 'Responder'),
(10, 78, 14, 'Driver'),   (16, 78, 14, 'Responder'),
(11, 79, 4,  'Driver'),   (2,  79, 4,  'Responder'),
(29, 80, 27, 'Driver'),   (24, 80, 27, 'Responder'),
(21, 81, 21, 'Responder'),(22, 81, 21, 'Support'),
(8,  82, 11, 'Driver'),   (13, 82, 11, 'Responder'),
(11, 83, 1,  'Driver'),   (1,  83, 1,  'Responder'),
(9,  84, 13, 'Driver'),   (15, 84, 13, 'Responder'),
(8,  85, 3,  'Driver'),   (4,  85, 3,  'Responder'),
(29, 86, 24, 'Driver'),   (25, 86, 24, 'Responder');

-- ------------------------------------------------------------
-- INCIDENT HISTORY: 100 records (status change audit trail)
-- ------------------------------------------------------------
INSERT INTO Incident_History (request_id, old_status, new_status, changed_by, remarks) VALUES
(1,'Pending','Assigned',6,'Ambulance dispatched'),
(1,'Assigned','In Progress',6,'Vehicle on scene'),
(1,'In Progress','Completed',6,'Patient transported'),
(2,'Pending','Assigned',7,'Police van assigned'),
(2,'Assigned','In Progress',7,'Officers at location'),
(2,'In Progress','Completed',7,'Accident report filed'),
(3,'Pending','Assigned',6,'Fire truck dispatched'),
(3,'Assigned','In Progress',6,'Fire brigade working'),
(3,'In Progress','Completed',6,'Fire extinguished'),
(4,'Pending','Assigned',8,'Police dispatched'),
(4,'Assigned','In Progress',8,'Chase initiated'),
(4,'In Progress','Completed',8,'Suspect apprehended'),
(5,'Pending','Assigned',6,'Ambulance assigned'),
(5,'Assigned','In Progress',6,'Arrived at flat'),
(5,'In Progress','Completed',6,'Child stabilized'),
(6,'Pending','Assigned',9,'Police assigned'),
(6,'Assigned','In Progress',9,'Officers on scene'),
(6,'In Progress','Completed',9,'Accident cleared'),
(7,'Pending','Assigned',6,'Fire truck assigned'),
(7,'Assigned','In Progress',6,'Fire contained'),
(7,'In Progress','Completed',6,'Building safe'),
(8,'Pending','Assigned',7,'Police van dispatched'),
(8,'Assigned','In Progress',7,'Officer at ATM'),
(8,'In Progress','Completed',7,'Witness statement taken'),
(9,'Pending','Assigned',8,'Ambulance dispatched'),
(9,'Assigned','In Progress',8,'Patient attended to'),
(9,'In Progress','Completed',8,'Discharged on scene'),
(10,'Pending','Assigned',10,'Ambulance assigned'),
(10,'Assigned','In Progress',10,'Patient treated'),
(10,'In Progress','Completed',10,'Transported to hospital'),
(11,'Pending','Assigned',6,'Fire truck dispatched'),
(11,'Assigned','In Progress',6,'Fire brigade on site'),
(11,'In Progress','Completed',6,'Explosion contained'),
(12,'Pending','Assigned',9,'Police assigned'),
(12,'Assigned','In Progress',9,'Officers investigating'),
(12,'In Progress','Completed',9,'FIR registered'),
(13,'Pending','Assigned',8,'Fire + Police dispatched'),
(13,'Assigned','In Progress',8,'Scene secured'),
(13,'In Progress','Completed',8,'Road cleared'),
(14,'Pending','Assigned',6,'Ambulance dispatched'),
(14,'Assigned','In Progress',6,'CPR initiated on scene'),
(14,'In Progress','Completed',6,'Patient in ICU'),
(15,'Pending','Assigned',7,'Police dispatched'),
(15,'Assigned','In Progress',7,'Victim secured'),
(15,'In Progress','Completed',7,'FIR registered'),
(16,'Pending','Assigned',8,'Police van assigned'),
(16,'Assigned','In Progress',8,'Scene reached'),
(16,'In Progress','Completed',8,'Offenders arrested'),
(17,'Pending','Assigned',9,'Fire truck dispatched'),
(17,'Assigned','In Progress',9,'Fire under control'),
(17,'In Progress','Completed',9,'Lab restored'),
(18,'Pending','Assigned',10,'Ambulance dispatched'),
(18,'Assigned','In Progress',10,'Delivery assisted'),
(18,'In Progress','Completed',10,'Mother and child safe'),
(19,'Pending','Assigned',6,'Police van dispatched'),
(19,'Assigned','In Progress',6,'Offender stopped'),
(19,'In Progress','Completed',6,'Case filed'),
(20,'Pending','Assigned',7,'Police van assigned'),
(20,'Assigned','In Progress',7,'Cyclist found'),
(20,'In Progress','Completed',7,'Hospital admitted'),
(21,'Pending','Assigned',8,'Ambulance dispatched'),
(21,'Assigned','In Progress',8,'Anti-venom given'),
(21,'In Progress','Completed',8,'Patient stable'),
(22,'Pending','Assigned',9,'Fire truck dispatched'),
(22,'Assigned','In Progress',9,'Smoke cleared'),
(22,'In Progress','Completed',9,'Area evacuated'),
(23,'Pending','Assigned',10,'Police dispatched'),
(23,'Assigned','In Progress',10,'Car spotted'),
(23,'In Progress','Completed',10,'Vehicle recovered'),
(24,'Pending','Assigned',6,'Ambulance dispatched'),
(24,'Assigned','In Progress',6,'Patient breathing assisted'),
(24,'In Progress','Completed',6,'Taken to hospital'),
(25,'Pending','Assigned',7,'Fire + Ambulance'),
(25,'Assigned','In Progress',7,'Multiple units on scene'),
(25,'In Progress','Completed',7,'All cleared'),
(77,'Pending','Assigned',8,'Fire trucks dispatched'),
(77,'Assigned','In Progress',8,'Firefighters on scene'),
(78,'Pending','Assigned',9,'Police force mobilized'),
(78,'Assigned','In Progress',9,'Crowd control active'),
(79,'Pending','Assigned',6,'Ambulance rushed'),
(79,'Assigned','In Progress',6,'Doctor attending'),
(80,'Pending','Assigned',10,'All teams dispatched'),
(80,'Assigned','In Progress',10,'Rescue operation active'),
(81,'Pending','Assigned',7,'Fire truck at hospital'),
(81,'Assigned','In Progress',7,'Fire brigade working'),
(82,'Pending','Assigned',8,'Police and bomb squad'),
(83,'Pending','Assigned',9,'Multiple ambulances'),
(84,'Pending','Assigned',10,'Road clearing team sent'),
(85,'Pending','Assigned',6,'Ambulance dispatched'),
(86,'Pending','Assigned',7,'Fire units deployed');

-- ------------------------------------------------------------
-- VEHICLE MAINTENANCE: 30 records (one per vehicle)
-- ------------------------------------------------------------
INSERT INTO Vehicle_Maintenance (vehicle_id, last_service_date, next_service_date, status, remarks) VALUES
(1,  '2025-12-01', '2026-03-01', 'OK',               'Routine check done'),
(2,  '2025-11-15', '2026-02-15', 'Needs Service',     'Oil change overdue'),
(3,  '2026-01-05', '2026-04-05', 'OK',                'Recently serviced'),
(4,  '2025-12-20', '2026-03-20', 'OK',                'All systems checked'),
(5,  '2025-09-01', '2025-12-01', 'Under Maintenance', 'Engine overhaul ongoing'),
(6,  '2026-01-02', '2026-04-02', 'OK',                'Full service done'),
(7,  '2025-10-10', '2026-01-10', 'Needs Service',     'Tyre rotation pending'),
(8,  '2026-01-10', '2026-04-10', 'OK',                'New battery installed'),
(9,  '2025-12-15', '2026-03-15', 'OK',                'Brake pads replaced'),
(10, '2025-08-01', '2025-11-01', 'Under Maintenance', 'Transmission repair'),
(11, '2026-01-01', '2026-04-01', 'OK',                'Full check completed'),
(12, '2025-11-01', '2026-02-01', 'Needs Service',     'Suspension check needed'),
(13, '2026-01-08', '2026-04-08', 'OK',                'Serviced last week'),
(14, '2025-12-10', '2026-03-10', 'OK',                'Lights and horn OK'),
(15, '2025-10-01', '2026-01-01', 'Needs Service',     'Coolant leak reported'),
(16, '2026-01-03', '2026-04-03', 'OK',                'GPS calibrated'),
(17, '2025-12-25', '2026-03-25', 'OK',                'AC serviced'),
(18, '2025-07-01', '2025-10-01', 'Under Maintenance', 'Full body repair'),
(19, '2026-01-12', '2026-04-12', 'OK',                'Tyres replaced'),
(20, '2025-11-20', '2026-02-20', 'OK',                'All lights functional'),
(21, '2026-01-05', '2026-04-05', 'OK',                'Water hose checked'),
(22, '2025-10-15', '2026-01-15', 'Needs Service',     'Pump pressure low'),
(23, '2026-01-09', '2026-04-09', 'OK',                'Ladder mechanism OK'),
(24, '2025-12-05', '2026-03-05', 'OK',                'Full service done'),
(25, '2025-09-20', '2025-12-20', 'Under Maintenance', 'Foam tank replacement'),
(26, '2026-01-11', '2026-04-11', 'OK',                'Compressor tested'),
(27, '2025-11-10', '2026-02-10', 'Needs Service',     'Fuel injector clogged'),
(28, '2026-01-06', '2026-04-06', 'OK',                'Hose reels replaced'),
(29, '2025-12-18', '2026-03-18', 'OK',                'Radio system updated'),
(30, '2026-01-14', '2026-04-14', 'OK',                'New fire extinguisher fitted');

-- ------------------------------------------------------------
-- AREA RESPONSE STATS: 15 areas
-- ------------------------------------------------------------
INSERT INTO Area_Response_Stats (area, total_requests, avg_response_time, max_response_time) VALUES
('Sector 17', 12, 8.3,  18.0),
('Sector 22', 11, 10.2, 14.0),
('Sector 11',  8,  8.5, 13.0),
('Sector 7',   7,  7.1,  9.0),
('Sector 34',  9,  8.9, 14.0),
('Sector 45',  6,  8.0, 10.0),
('Sector 9',   7,  7.7,  9.0),
('Sector 56',  5, 10.0, 14.0),
('Sector 63',  6,  8.3, 12.0),
('Sector 19',  5,  8.4, 10.0),
('Sector 12',  3,  9.0, 11.0),
('Sector 48',  2, 12.0, 14.0),
('Sector 72',  2,  7.5,  8.0),
('Sector 15',  3,  8.7, 10.0),
('Sector 28',  2, 11.0, 13.0);

-- ------------------------------------------------------------
-- VEHICLE LOCATION LOGS: 30 records
-- ------------------------------------------------------------
INSERT INTO Vehicle_Log (vehicle_id, latitude, longitude) VALUES
(1, 30.7340, 76.7800),(1, 30.7338, 76.7801),(1, 30.7336, 76.7803),
(2, 30.7420, 76.7815),(2, 30.7418, 76.7814),
(3, 30.7510, 76.8012),(3, 30.7512, 76.8013),
(4, 30.7502, 76.8002),(4, 30.7505, 76.8005),
(5, 30.7080, 76.7485),(5, 30.7082, 76.7487),
(6, 30.7255, 76.7708),(6, 30.7258, 76.7710),
(7, 30.7260, 76.7712),
(8, 30.7495, 76.7992),(8, 30.7498, 76.7995),
(11,30.7405, 76.7807),(11,30.7408, 76.7809),
(13,30.7408, 76.7808),
(14,30.7112, 76.7615),(14,30.7115, 76.7618),
(16,30.7205, 76.7508),
(21,30.7255, 76.7705),(21,30.7258, 76.7708),
(22,30.7220, 76.7520),
(24,30.7150, 76.7655),(24,30.7152, 76.7658),
(27,30.7060, 76.7562),(27,30.7062, 76.7565),
(28,30.7158, 76.7660);

-- ------------------------------------------------------------
-- NOTIFICATIONS: 30 records
-- ------------------------------------------------------------
INSERT INTO Notifications (user_id, message, type, status) VALUES
(16,'Your request #1 received. Ambulance dispatched.','Dispatch','Read'),
(16,'Ambulance has arrived at your location.','Status Update','Read'),
(17,'Police unit assigned to your accident report.','Dispatch','Read'),
(17,'Officers have arrived on scene.','Status Update','Read'),
(18,'Fire brigade on the way. Please evacuate.','Alert','Read'),
(19,'Police dispatched to your robbery report.','Dispatch','Read'),
(20,'Ambulance assigned for the child. Stay calm.','Dispatch','Read'),
(21,'Police help is on the way.','Dispatch','Read'),
(22,'Fire truck dispatched to your location.','Dispatch','Read'),
(23,'Police assigned — ATM theft reported.','Dispatch','Read'),
(24,'Ambulance dispatched for fracture case.','Dispatch','Read'),
(25,'Ambulance on the way — diabetic emergency.','Dispatch','Read'),
(26,'Fire brigade responding to LPG blast.','Alert','Read'),
(27,'Police assigned to break-in report.','Dispatch','Read'),
(28,'Fire and rescue teams dispatched.','Alert','Read'),
(29,'Ambulance en route — cardiac emergency.','Alert','Read'),
(30,'Police dispatched — domestic violence case.','Dispatch','Read'),
(31,'Police units assigned.','Dispatch','Read'),
(32,'Fire truck dispatched to school.','Alert','Read'),
(33,'Ambulance rushing for maternity emergency.','Alert','Read'),
(67,'Ambulance dispatched for fracture.','Dispatch','Read'),
(68,'Fire + Police dispatched.','Alert','Read'),
(77,'Fire brigade responding to slum fire.','Alert','Unread'),
(78,'Police force mobilized for riot control.','Alert','Unread'),
(79,'Ambulance rushing for maternity case.','Alert','Unread'),
(80,'All rescue teams deployed — bridge collapse.','Alert','Unread'),
(81,'Fire brigade at hospital.','Alert','Unread'),
(82,'Bomb squad and police dispatched.','Alert','Unread'),
(83,'Multiple ambulances dispatched.','Alert','Unread'),
(84,'Road clearing teams assigned.','Info','Unread');

-- ------------------------------------------------------------
-- FEEDBACK: 50 records (for completed emergencies)
-- ------------------------------------------------------------
INSERT INTO Feedback (request_id, user_id, rating, comments) VALUES
(1,  16, 5, 'Very fast response. Paramedics were outstanding.'),
(2,  17, 4, 'Police arrived quickly. Road clearance took time.'),
(3,  18, 5, 'Fire brigade was brave and efficient.'),
(4,  19, 4, 'Robber caught quickly. Great police work.'),
(5,  20, 5, 'Ambulance saved my child. Eternally grateful.'),
(6,  21, 3, 'Took a little longer than expected.'),
(7,  22, 4, 'Fire was controlled before it spread further.'),
(8,  23, 4, 'Police responded quickly to chain snatching.'),
(9,  24, 5, 'Great ambulance service for elderly patient.'),
(10, 25, 5, 'Ambulance arrived very fast. Good crew.'),
(11, 26, 5, 'Fire brigade handled LPG blast perfectly.'),
(12, 27, 3, 'Police came but burglar had already escaped.'),
(13, 28, 4, 'Good response to highway accident.'),
(14, 29, 5, 'Cardiac emergency handled brilliantly.'),
(15, 30, 4, 'Victim is safe. Thankful to police.'),
(16, 31, 3, 'Response was okay but could be faster.'),
(17, 32, 4, 'Fire in school was contained well.'),
(18, 33, 5, 'Ambulance team delivered the baby safely. Heroes.'),
(19, 34, 4, 'Drunk driver was stopped promptly.'),
(20, 35, 5, 'Cyclist saved. Excellent first aid on scene.'),
(21, 36, 5, 'Anti-venom given on time. Life saved.'),
(22, 37, 4, 'Warehouse fire managed with good teamwork.'),
(23, 38, 2, 'Car already gone before police arrived.'),
(24, 39, 4, 'Asthma patient given oxygen promptly.'),
(25, 40, 5, 'Multi-vehicle accident cleared fast.'),
(26, 41, 4, 'Office fire extinguished before damage spread.'),
(27, 42, 3, 'Suspect escaped. Police filed report only.'),
(28, 43, 4, 'Elderly patient got timely care.'),
(29, 44, 5, 'Drowning victim rescued just in time!'),
(30, 45, 4, 'Restaurant fire was put out efficiently.'),
(31, 46, 3, 'Cybercafe robber got away but report filed.'),
(32, 47, 5, 'Pedestrian victim got immediate care.'),
(33, 48, 4, 'Food poisoning victims stabilized quickly.'),
(34, 49, 4, 'Forest fire stopped from entering colony.'),
(35, 50, 5, 'Quick action prevented kidnapping. Great work.'),
(36, 51, 5, 'Electrocution victim survived due to quick response.'),
(37, 52, 4, 'Train crossing rescue was handled safely.'),
(38, 53, 4, 'AC blast fire was controlled promptly.'),
(39, 54, 2, 'Theft already done, just report filed.'),
(40, 55, 5, 'Child with seizures was attended to immediately.'),
(41, 56, 5, 'Car in ditch rescue was perfect.'),
(42, 57, 3, 'Fire took longer to extinguish.'),
(43, 58, 2, 'Drug peddlers disappeared, just FIR done.'),
(44, 59, 4, 'Dog bite victim vaccinated promptly.'),
(45, 60, 4, 'Child from bus fall cared for well.'),
(46, 61, 5, 'Gas pipeline fire handled bravely.'),
(47, 62, 5, 'Suicide attempt prevented. Amazing police response.'),
(48, 63, 5, 'Stroke patient reached hospital in time.'),
(49, 64, 5, 'Head-on collision victims all survived.'),
(50, 65, 4, 'Chemical fire handled with proper gear.');


-- ============================================================
-- SECTION 3: VIEWS
-- ============================================================

CREATE VIEW Active_Requests AS
SELECT er.request_id, er.emergency_type, er.location, er.severity_level,
       er.status, er.request_time, u.name AS reported_by
FROM Emergency_Request er
JOIN Users u ON er.user_id = u.user_id
WHERE er.status IN ('Pending','Assigned','In Progress');

CREATE VIEW Available_Vehicles AS
SELECT ev.vehicle_id, ev.vehicle_type, ev.license_plate,
       ev.driver_name, ev.driver_phone,
       sc.center_name, sc.service_type, sc.area
FROM Emergency_Vehicle ev
JOIN Service_Center sc ON ev.center_id = sc.center_id
WHERE ev.availability = 'Available';

CREATE VIEW Full_Dispatch_Report AS
SELECT dr.dispatch_id,
       er.request_id, er.emergency_type, er.location,
       u.name AS citizen_name, u.phone_number,
       ev.vehicle_type, ev.license_plate, ev.driver_name,
       op.name AS operator_name,
       dr.dispatch_time, dr.arrival_time, dr.completion_time,
       dr.response_time, dr.status AS dispatch_status
FROM Dispatch_Record dr
JOIN Emergency_Request er  ON dr.request_id  = er.request_id
JOIN Users u               ON er.user_id     = u.user_id
JOIN Emergency_Vehicle ev  ON dr.vehicle_id  = ev.vehicle_id
JOIN Users op              ON dr.operator_id = op.user_id;

CREATE VIEW Active_Staff_Assignments AS
SELECT sa.assignment_id, ss.name AS staff_name, ss.role,
       er.request_id, er.emergency_type, er.location,
       sa.role_in_emergency, sa.assigned_time
FROM Staff_Assignment sa
JOIN Service_Staff ss      ON sa.staff_id   = ss.staff_id
JOIN Emergency_Request er  ON sa.request_id = er.request_id
WHERE er.status IN ('Assigned','In Progress');

CREATE VIEW Maintenance_Due AS
SELECT ev.vehicle_id, ev.vehicle_type, ev.license_plate,
       sc.area, vm.last_service_date, vm.next_service_date, vm.status, vm.remarks
FROM Vehicle_Maintenance vm
JOIN Emergency_Vehicle ev ON vm.vehicle_id = ev.vehicle_id
JOIN Service_Center sc    ON ev.center_id  = sc.center_id
WHERE vm.status IN ('Needs Service','Under Maintenance');


-- ============================================================
-- SECTION 4: SELECT QUERIES
-- ============================================================

-- Q1: All requests with citizen name and phone
SELECT er.request_id, er.emergency_type, er.location,
       er.severity_level, er.status, er.request_time,
       u.name, u.phone_number
FROM Emergency_Request er
JOIN Users u ON er.user_id = u.user_id
ORDER BY er.request_time DESC;

-- Q2: Pending requests ordered by severity (Operator View)
SELECT er.request_id, er.emergency_type, er.location,
       er.severity_level, u.name AS reported_by
FROM Emergency_Request er
JOIN Users u ON er.user_id = u.user_id
WHERE er.status = 'Pending'
ORDER BY er.severity_level DESC;

-- Q3: Full dispatch details with vehicle and operator
SELECT dr.dispatch_id, er.emergency_type, er.location,
       ev.vehicle_type, ev.driver_name, op.name AS operator,
       dr.dispatch_time, dr.arrival_time, dr.response_time
FROM Dispatch_Record dr
JOIN Emergency_Request er ON dr.request_id = er.request_id
JOIN Emergency_Vehicle ev ON dr.vehicle_id = ev.vehicle_id
JOIN Users op             ON dr.operator_id = op.user_id;

-- Q4: Average and max response time per area (Admin Analytics)
SELECT er.location,
       COUNT(*) AS total_emergencies,
       ROUND(AVG(TIMESTAMPDIFF(MINUTE, dr.dispatch_time, dr.arrival_time)),2) AS avg_response_mins,
       MAX(TIMESTAMPDIFF(MINUTE, dr.dispatch_time, dr.arrival_time)) AS max_response_mins
FROM Emergency_Request er
JOIN Dispatch_Record dr ON er.request_id = dr.request_id
WHERE dr.arrival_time IS NOT NULL
GROUP BY er.location
ORDER BY avg_response_mins DESC;

-- Q5: Emergency count by type with completion rate
SELECT emergency_type,
       COUNT(*) AS total,
       SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END) AS completed,
       SUM(CASE WHEN status='Pending'   THEN 1 ELSE 0 END) AS pending,
       ROUND(SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END)*100.0/COUNT(*),1) AS completion_pct
FROM Emergency_Request
GROUP BY emergency_type;

-- Q6: Vehicles with dispatch count and current status
SELECT ev.vehicle_id, ev.vehicle_type, ev.license_plate,
       ev.availability, sc.area,
       COUNT(dr.dispatch_id) AS total_dispatches
FROM Emergency_Vehicle ev
JOIN Service_Center sc ON ev.center_id = sc.center_id
LEFT JOIN Dispatch_Record dr ON ev.vehicle_id = dr.vehicle_id
GROUP BY ev.vehicle_id
ORDER BY total_dispatches DESC;

-- Q7: Staff assignment overview with counts
SELECT ss.staff_id, ss.name, ss.role, ss.availability,
       COUNT(sa.assignment_id) AS total_assignments
FROM Service_Staff ss
LEFT JOIN Staff_Assignment sa ON ss.staff_id = sa.staff_id
GROUP BY ss.staff_id
ORDER BY total_assignments DESC;

-- Q8: Severity distribution with percentage
SELECT severity_level,
       COUNT(*) AS total_requests,
       ROUND(COUNT(*)*100.0/(SELECT COUNT(*) FROM Emergency_Request),1) AS percentage
FROM Emergency_Request
GROUP BY severity_level
ORDER BY severity_level DESC;

-- Q9: Operator performance — dispatches handled and avg response time
SELECT u.name AS operator_name,
       COUNT(dr.dispatch_id) AS dispatches_handled,
       ROUND(AVG(dr.response_time),2) AS avg_response_time
FROM Users u
JOIN Dispatch_Record dr ON u.user_id = dr.operator_id
GROUP BY u.user_id
ORDER BY dispatches_handled DESC;

-- Q10: Average feedback rating per emergency type
SELECT er.emergency_type,
       ROUND(AVG(f.rating),2) AS avg_rating,
       COUNT(f.feedback_id) AS total_reviews,
       MIN(f.rating) AS lowest_rating, MAX(f.rating) AS highest_rating
FROM Feedback f
JOIN Emergency_Request er ON f.request_id = er.request_id
GROUP BY er.emergency_type;

-- Q11: Monthly emergency count trend
SELECT DATE_FORMAT(request_time,'%Y-%m') AS month,
       COUNT(*) AS total_requests,
       SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END) AS resolved
FROM Emergency_Request
GROUP BY month
ORDER BY month;

-- Q12: Citizen's own request history (for logged-in citizen user_id=16)
SELECT er.request_id, er.emergency_type, er.location,
       er.severity_level, er.status, er.request_time,
       dr.dispatch_time, dr.arrival_time, dr.response_time
FROM Emergency_Request er
LEFT JOIN Dispatch_Record dr ON er.request_id = dr.request_id
WHERE er.user_id = 16;


-- ============================================================
-- SECTION 5: SUBQUERIES
-- ============================================================

-- SQ1: Available vehicles not in any active dispatch
SELECT vehicle_id, vehicle_type, license_plate
FROM Emergency_Vehicle
WHERE vehicle_id NOT IN (
    SELECT vehicle_id FROM Dispatch_Record
    WHERE completion_time IS NULL AND vehicle_id IS NOT NULL
);

-- SQ2: Citizens who reported at least one emergency
SELECT name, phone_number
FROM Users
WHERE user_id IN (SELECT DISTINCT user_id FROM Emergency_Request)
AND role = 'Citizen';

-- SQ3: Requests with above-average severity
SELECT request_id, emergency_type, location, severity_level
FROM Emergency_Request
WHERE severity_level > (SELECT AVG(severity_level) FROM Emergency_Request);

-- SQ4: Most dispatched vehicle
SELECT vehicle_id, vehicle_type, license_plate
FROM Emergency_Vehicle
WHERE vehicle_id = (
    SELECT vehicle_id FROM Dispatch_Record
    GROUP BY vehicle_id ORDER BY COUNT(*) DESC LIMIT 1
);

-- SQ5: Requests with no dispatch record yet
SELECT request_id, emergency_type, location, status, request_time
FROM Emergency_Request
WHERE request_id NOT IN (SELECT DISTINCT request_id FROM Dispatch_Record);

-- SQ6: Operators who handled at least one emergency
SELECT name, email
FROM Users
WHERE user_id IN (SELECT DISTINCT operator_id FROM Dispatch_Record)
AND role = 'Operator';

-- SQ7: Areas with above-average emergency count
SELECT location, COUNT(*) AS total
FROM Emergency_Request
GROUP BY location
HAVING COUNT(*) > (
    SELECT AVG(cnt) FROM (
        SELECT COUNT(*) AS cnt FROM Emergency_Request GROUP BY location
    ) AS temp
);

-- SQ8: Vehicles needing service but currently in service
SELECT vehicle_id, vehicle_type, availability
FROM Emergency_Vehicle
WHERE vehicle_id IN (
    SELECT vehicle_id FROM Vehicle_Maintenance
    WHERE status IN ('Needs Service','Under Maintenance')
) AND availability != 'Maintenance';

-- SQ9: Latest emergency per type
SELECT * FROM Emergency_Request er1
WHERE request_time = (
    SELECT MAX(request_time) FROM Emergency_Request er2
    WHERE er2.emergency_type = er1.emergency_type
);

-- SQ10: Staff never assigned to any emergency
SELECT staff_id, name, role
FROM Service_Staff
WHERE staff_id NOT IN (SELECT DISTINCT staff_id FROM Staff_Assignment);

-- SQ11: Requests with above-average response time
SELECT dr.dispatch_id, er.location, dr.response_time
FROM Dispatch_Record dr
JOIN Emergency_Request er ON dr.request_id = er.request_id
WHERE dr.response_time > (SELECT AVG(response_time) FROM Dispatch_Record WHERE response_time IS NOT NULL);

-- SQ12: Top-rated service areas (avg rating > 4)
SELECT er.location, ROUND(AVG(f.rating),2) AS avg_rating
FROM Feedback f
JOIN Emergency_Request er ON f.request_id = er.request_id
GROUP BY er.location
HAVING AVG(f.rating) > 4
ORDER BY avg_rating DESC;


-- ============================================================
-- SECTION 6: TRIGGERS (PL/SQL)
-- ============================================================

DELIMITER $$

-- TRIGGER 1: Auto-free vehicle and staff when dispatch completed
CREATE TRIGGER after_dispatch_complete
AFTER UPDATE ON Dispatch_Record
FOR EACH ROW
BEGIN
    IF NEW.completion_time IS NOT NULL AND OLD.completion_time IS NULL THEN
        UPDATE Emergency_Vehicle SET availability = 'Available'
        WHERE vehicle_id = NEW.vehicle_id;

        UPDATE Service_Staff SET availability = 'Available'
        WHERE staff_id IN (
            SELECT staff_id FROM Staff_Assignment WHERE request_id = NEW.request_id
        );

        UPDATE Emergency_Request SET status = 'Completed'
        WHERE request_id = NEW.request_id;

        INSERT INTO Incident_History (request_id, old_status, new_status, remarks)
        VALUES (NEW.request_id, 'In Progress', 'Completed', 'Auto-completed on dispatch close');
    END IF;
END$$

-- TRIGGER 2: Log every status change of Emergency_Request
CREATE TRIGGER log_request_status_change
AFTER UPDATE ON Emergency_Request
FOR EACH ROW
BEGIN
    IF NEW.status != OLD.status THEN
        INSERT INTO Incident_History (request_id, old_status, new_status, remarks)
        VALUES (NEW.request_id, OLD.status, NEW.status, 'Auto-logged by status trigger');
    END IF;
END$$

-- TRIGGER 3: Prevent dispatch if vehicle not available
CREATE TRIGGER before_dispatch_insert
BEFORE INSERT ON Dispatch_Record
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    SELECT availability INTO v_status FROM Emergency_Vehicle WHERE vehicle_id = NEW.vehicle_id;
    IF v_status != 'Available' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot dispatch: Vehicle is not Available';
    END IF;
END$$

-- TRIGGER 4: Auto-update Area_Response_Stats when dispatch completes
CREATE TRIGGER update_area_stats
AFTER UPDATE ON Dispatch_Record
FOR EACH ROW
BEGIN
    DECLARE req_location VARCHAR(255);
    DECLARE resp_time    INT;

    IF NEW.completion_time IS NOT NULL AND OLD.completion_time IS NULL THEN
        SELECT location INTO req_location FROM Emergency_Request WHERE request_id = NEW.request_id;
        SET resp_time = NEW.response_time;

        INSERT INTO Area_Response_Stats (area, total_requests, avg_response_time, max_response_time)
        VALUES (req_location, 1, resp_time, resp_time)
        ON DUPLICATE KEY UPDATE
            total_requests    = total_requests + 1,
            avg_response_time = ((avg_response_time * (total_requests - 1)) + resp_time) / total_requests,
            max_response_time = GREATEST(max_response_time, resp_time);
    END IF;
END$$

-- TRIGGER 5: Auto-notify citizen when request is assigned
CREATE TRIGGER notify_citizen_on_assign
AFTER UPDATE ON Emergency_Request
FOR EACH ROW
BEGIN
    IF NEW.status = 'Assigned' AND OLD.status = 'Pending' THEN
        INSERT INTO Notifications (user_id, message, type)
        VALUES (NEW.user_id,
            CONCAT('Your emergency request #', NEW.request_id, ' has been assigned. Help is on the way!'),
            'Dispatch');
    END IF;
END$$

DELIMITER ;


-- ============================================================
-- SECTION 7: STORED PROCEDURES (PL/SQL)
-- ============================================================

DELIMITER $$

-- PROCEDURE 1: AssignVehicle — with transaction + exception handling
CREATE PROCEDURE AssignVehicle(
    IN  req_id         INT,
    OUT result_message VARCHAR(255)
)
BEGIN
    DECLARE v_id       INT DEFAULT NULL;
    DECLARE req_type   VARCHAR(50);
    DECLARE req_exists INT DEFAULT 0;
    DECLARE svc_type   VARCHAR(50);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET result_message = 'ERROR: Vehicle assignment failed. Transaction rolled back.';
    END;

    START TRANSACTION;

    SELECT COUNT(*), emergency_type
    INTO req_exists, req_type
    FROM Emergency_Request
    WHERE request_id = req_id AND status = 'Pending';

    IF req_exists = 0 THEN
        ROLLBACK;
        SET result_message = 'ERROR: Request not found or already processed.';
    ELSE
        SET svc_type = CASE req_type
            WHEN 'Medical'  THEN 'Ambulance'
            WHEN 'Fire'     THEN 'Fire'
            WHEN 'Crime'    THEN 'Police'
        END;

        SELECT ev.vehicle_id INTO v_id
        FROM Emergency_Vehicle ev
        JOIN Service_Center sc ON ev.center_id = sc.center_id
        WHERE ev.availability = 'Available' AND sc.service_type = svc_type
        LIMIT 1;

        IF v_id IS NULL THEN
            ROLLBACK;
            SET result_message = CONCAT('ERROR: No available vehicle of type ', svc_type);
        ELSE
            INSERT INTO Dispatch_Record (request_id, vehicle_id, status)
            VALUES (req_id, v_id, 'Assigned');

            UPDATE Emergency_Vehicle SET availability = 'Busy' WHERE vehicle_id = v_id;
            UPDATE Emergency_Request  SET status = 'Assigned'  WHERE request_id = req_id;

            COMMIT;
            SET result_message = CONCAT('SUCCESS: Vehicle #', v_id, ' assigned to Request #', req_id);
        END IF;
    END IF;
END$$


-- PROCEDURE 2: AssignStaffToRequest — CURSOR-based, most complex procedure
CREATE PROCEDURE AssignStaffToRequest(
    IN  req_id         INT,
    IN  req_type       VARCHAR(50),
    OUT assigned_count INT
)
BEGIN
    DECLARE done       INT DEFAULT FALSE;
    DECLARE s_id       INT;
    DECLARE s_role     VARCHAR(50);
    DECLARE max_staff  INT DEFAULT 3;
    DECLARE req_role   VARCHAR(50);

    SET req_role = CASE req_type
        WHEN 'Medical'  THEN 'Paramedic'
        WHEN 'Fire'     THEN 'Firefighter'
        WHEN 'Crime'    THEN 'Police'
        WHEN 'Accident' THEN 'Paramedic'
        ELSE                 'Driver'
    END;

    -- Cursor: fetch available matching staff
    DECLARE staff_cursor CURSOR FOR
        SELECT staff_id, role FROM Service_Staff
        WHERE availability = 'Available'
          AND role IN (req_role, 'Driver')
        ORDER BY FIELD(role, req_role, 'Driver')
        LIMIT 3;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    SET assigned_count = 0;

    OPEN staff_cursor;

    staff_loop: LOOP
        IF assigned_count >= max_staff THEN LEAVE staff_loop; END IF;
        FETCH staff_cursor INTO s_id, s_role;
        IF done THEN LEAVE staff_loop; END IF;

        INSERT INTO Staff_Assignment (staff_id, request_id, role_in_emergency)
        VALUES (s_id, req_id,
            CASE s_role WHEN 'Driver' THEN 'Driver' ELSE 'Responder' END);

        UPDATE Service_Staff SET availability = 'Assigned' WHERE staff_id = s_id;
        SET assigned_count = assigned_count + 1;
    END LOOP;

    CLOSE staff_cursor;
END$$


-- PROCEDURE 3: CompleteEmergency — mark dispatch done, triggers free resources
CREATE PROCEDURE CompleteEmergency(
    IN  dispatch_id_in INT,
    OUT result_message VARCHAR(255)
)
BEGIN
    DECLARE dispatch_exists INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET result_message = 'ERROR: Could not complete. Transaction rolled back.';
    END;

    START TRANSACTION;

    SELECT COUNT(*) INTO dispatch_exists
    FROM Dispatch_Record
    WHERE dispatch_id = dispatch_id_in AND status IN ('Assigned','In Progress');

    IF dispatch_exists = 0 THEN
        ROLLBACK;
        SET result_message = 'ERROR: Dispatch not found or already completed.';
    ELSE
        UPDATE Dispatch_Record
        SET completion_time = CURRENT_TIMESTAMP,
            status          = 'Completed',
            response_time   = TIMESTAMPDIFF(MINUTE, dispatch_time, CURRENT_TIMESTAMP)
        WHERE dispatch_id = dispatch_id_in;
        COMMIT;
        SET result_message = CONCAT('SUCCESS: Dispatch #', dispatch_id_in, ' completed.');
    END IF;
END$$


-- PROCEDURE 4: GetEmergencyDetails — multi-result set for admin view
CREATE PROCEDURE GetEmergencyDetails(IN req_id INT)
BEGIN
    SELECT er.request_id, er.emergency_type, er.description,
           er.location, er.severity_level, er.status, er.request_time,
           u.name AS citizen, u.phone_number
    FROM Emergency_Request er
    JOIN Users u ON er.user_id = u.user_id
    WHERE er.request_id = req_id;

    SELECT dr.dispatch_id, ev.vehicle_type, ev.license_plate, ev.driver_name,
           op.name AS operator, dr.dispatch_time, dr.arrival_time,
           dr.completion_time, dr.response_time, dr.status
    FROM Dispatch_Record dr
    JOIN Emergency_Vehicle ev ON dr.vehicle_id  = ev.vehicle_id
    JOIN Users op             ON dr.operator_id = op.user_id
    WHERE dr.request_id = req_id;

    SELECT ss.name AS staff_name, ss.role, sa.role_in_emergency, sa.assigned_time
    FROM Staff_Assignment sa
    JOIN Service_Staff ss ON sa.staff_id = ss.staff_id
    WHERE sa.request_id = req_id;

    SELECT old_status, new_status, change_time, remarks
    FROM Incident_History
    WHERE request_id = req_id
    ORDER BY change_time ASC;
END$$


-- PROCEDURE 5: CancelRequest
CREATE PROCEDURE CancelRequest(
    IN  req_id         INT,
    IN  cancelled_by   INT,
    OUT result_message VARCHAR(255)
)
BEGIN
    DECLARE current_status VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET result_message = 'ERROR: Cancellation failed.';
    END;

    START TRANSACTION;

    SELECT status INTO current_status FROM Emergency_Request WHERE request_id = req_id;

    IF current_status IN ('Completed','Cancelled') THEN
        ROLLBACK;
        SET result_message = 'ERROR: Cannot cancel a completed/cancelled request.';
    ELSE
        UPDATE Emergency_Request SET status = 'Cancelled' WHERE request_id = req_id;

        INSERT INTO Incident_History (request_id, old_status, new_status, changed_by, remarks)
        VALUES (req_id, current_status, 'Cancelled', cancelled_by, 'Manually cancelled by user/admin');

        COMMIT;
        SET result_message = CONCAT('SUCCESS: Request #', req_id, ' cancelled.');
    END IF;
END$$

DELIMITER ;


-- ============================================================
-- SECTION 8: FUNCTIONS (PL/SQL)
-- ============================================================

DELIMITER $$

-- FUNCTION 1: Get response time in minutes for a request
CREATE FUNCTION GetResponseTime(req_id INT)
RETURNS DECIMAL(6,2)
DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE resp_time DECIMAL(6,2);
    SELECT TIMESTAMPDIFF(MINUTE, dispatch_time, arrival_time)
    INTO resp_time
    FROM Dispatch_Record
    WHERE request_id = req_id AND arrival_time IS NOT NULL
    LIMIT 1;
    RETURN IFNULL(resp_time, -1);
END$$

-- FUNCTION 2: Convert severity number to priority label
CREATE FUNCTION GetPriorityLabel(severity INT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    RETURN CASE
        WHEN severity = 5 THEN 'CRITICAL'
        WHEN severity = 4 THEN 'HIGH'
        WHEN severity = 3 THEN 'MEDIUM'
        WHEN severity = 2 THEN 'LOW'
        ELSE                    'MINIMAL'
    END;
END$$

-- FUNCTION 3: Count active emergencies in an area
CREATE FUNCTION GetActiveCountByArea(area_name VARCHAR(100))
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE total INT;
    SELECT COUNT(*) INTO total
    FROM Emergency_Request
    WHERE location LIKE CONCAT('%', area_name, '%')
      AND status IN ('Pending','Assigned','In Progress');
    RETURN IFNULL(total, 0);
END$$

-- FUNCTION 4: Check if vehicle is free (1=free, 0=not free)
CREATE FUNCTION IsVehicleFree(v_id INT)
RETURNS TINYINT(1)
READS SQL DATA
BEGIN
    DECLARE v_status VARCHAR(20);
    SELECT availability INTO v_status FROM Emergency_Vehicle WHERE vehicle_id = v_id;
    RETURN IF(v_status = 'Available', 1, 0);
END$$

DELIMITER ;


-- ============================================================
-- SECTION 9: SAMPLE PROCEDURE & FUNCTION CALLS
-- ============================================================

-- Assign vehicle to pending request 87
SET @msg = '';
CALL AssignVehicle(87, @msg);
SELECT @msg AS result;

-- Assign staff to request 88 (medical)
SET @cnt = 0;
CALL AssignStaffToRequest(88, 'Medical', @cnt);
SELECT @cnt AS staff_assigned;

-- Get response time for requests
SELECT request_id, emergency_type,
       GetResponseTime(request_id) AS response_mins,
       GetPriorityLabel(severity_level) AS priority
FROM Emergency_Request LIMIT 20;

-- Count active emergencies in Sector 22
SELECT GetActiveCountByArea('Sector 22') AS active_sector22;

-- Check which vehicles are currently free
SELECT vehicle_id, vehicle_type, license_plate,
       IsVehicleFree(vehicle_id) AS is_free
FROM Emergency_Vehicle;

-- Get full details for emergency request 14
CALL GetEmergencyDetails(14);

-- Cancel request 95 (trivial fake currency report, no dispatch yet)
SET @cancel_msg = '';
CALL CancelRequest(95, 1, @cancel_msg);
SELECT @cancel_msg AS cancel_result;


-- ============================================================
-- SECTION 10: TRANSACTION EXAMPLE
-- ============================================================

START TRANSACTION;
    SAVEPOINT before_assign;

    INSERT INTO Dispatch_Record (request_id, vehicle_id, operator_id, status)
    VALUES (89, 17, 8, 'Assigned');

    UPDATE Emergency_Vehicle SET availability = 'Busy' WHERE vehicle_id = 17;
    UPDATE Emergency_Request  SET status = 'Assigned' WHERE request_id = 89;

COMMIT;
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- END OF FILE
-- ============================================================
-- Tables:     14   |  Users:           100
-- Views:       5   |  Vehicles:         30
-- Triggers:    5   |  Staff:            30
-- Procedures:  5   |  Requests:        100
-- Functions:   4   |  Dispatches:       86
--                  |  Staff Assignments:100
--                  |  Incident History: 100
--                  |  Maintenance:       30
--                  |  Feedback:          50
--                  |  Notifications:     30
--                  |  Vehicle Logs:      30
--                  |  Area Stats:        15
-- ============================================================
