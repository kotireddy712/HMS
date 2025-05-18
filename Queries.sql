--@block
DROP DATABASE hms_db;

--@block
SELECT *FROM student;

--@block
USE hms_db;

--@block
CREATE TABLE student (
    student_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email_id VARCHAR(255) UNIQUE NOT NULL,
    contact_number VARCHAR(15) NOT NULL,
    password VARCHAR(255) NOT NULL,
    date_of_birth DATE NOT NULL,
    gender CHAR(1) CHECK (gender IN ('M', 'F', 'O')),
    room VARCHAR(50),
    hostel_name VARCHAR(10),
    first_login_date DATETIME DEFAULT NULL
);

 -- 3-NF FAILED..
  
--@block
CREATE TABLE room (
    room_number VARCHAR(10) PRIMARY KEY,
    hostel_name VARCHAR(5),
    available_space INT
);


--@block
ALTER TABLE student
ADD CONSTRAINT fk_student_room
FOREIGN KEY (room) REFERENCES room(room_number) 
ON DELETE SET NULL;

--@block
CREATE TABLE hostel (
    hostel_name VARCHAR(10) PRIMARY KEY,
    hostel_admin_id VARCHAR(20) NOT NULL,
    total_rooms INT NOT NULL,
    total_students_present INT NOT NULL
);

--@block
INSERT INTO hostel (hostel_name, hostel_admin_id, total_rooms, total_students_present) VALUES
('A', 'S254323', 100, 0),
('B', 'S258477', 100, 0),
('C', 'S254305', 100, 0),
('G', 'S251545', 100, 0);

--@block
ALTER TABLE room
ADD CONSTRAINT fk_room_hostel
FOREIGN KEY (hostel_name) REFERENCES hostel(hostel_name)
ON DELETE CASCADE;

--@block
CREATE TABLE maintenance_request (
    request_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id VARCHAR(20) NOT NULL,
    room_number VARCHAR(10) ,
    request_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    description TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'Pending',
    FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE
);

--@block
CREATE TABLE  staff (
    staff_id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email_id VARCHAR(255) UNIQUE NOT NULL,
    contact_number VARCHAR(15) NOT NULL,
    hostel_name VARCHAR(100) NOT NULL,
    designation VARCHAR(50) NOT NULL, -- Changed from ENUM to VARCHAR
    gender VARCHAR(10) NOT NULL, -- Changed from ENUM to VARCHAR
    password VARCHAR(255) DEFAULT NULL -- Can be NULL (only required for admin)
);

--@block

CREATE TABLE fee_payment (
    payment_id VARCHAR(50) PRIMARY KEY,
    student_id VARCHAR(20) NOT NULL UNIQUE,
    amount INT NOT NULL,
    payment_status VARCHAR(20) DEFAULT 'Pending',
    payment_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE
);
--@block
ALTER TABLE student ADD fee_status VARCHAR(20) DEFAULT 'Unpaid';

--@block
CREATE TABLE student_leave (
    leave_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id VARCHAR(255) NOT NULL,
    start_date DATE NOT NULL,
    return_date DATE NOT NULL,
    reason VARCHAR(255) NOT NULL,
    status VARCHAR(20) DEFAULT 'On leave',
    FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE
);

--@block
SELECT * FROM student_leave;
--@block
ALTER TABLE hostel
ADD CONSTRAINT fk_hostel_staff
FOREIGN KEY (hostel_admin_id) REFERENCES staff(staff_id)
ON DELETE CASCADE;

--@block
ALTER TABLE hostel
DROP FOREIGN KEY fk1_student_hostel;

--@block
ALTER TABLE student
DROP FOREIGN KEY fk_student_hostel;

--@block
ALTER TABLE student
ADD CONSTRAINT fk1_student_hostel
FOREIGN KEY (hostel_name) REFERENCES hostel(hostel_name) ON DELETE SET NULL;

--@block
 STUDENT DASHBOARD QUERIES

1. Login & Session Management

-- Verify student credentials
SELECT student_id, name FROM student WHERE email_id=%s AND password=%s

-- Update first login timestamp (only on first login)
UPDATE student SET first_login_date = NOW() WHERE student_id = %s AND first_login_date IS NULL

2. Dashboard & Profile

-- Fetch fee status (displayed on dashboard)
SELECT fee_status FROM student WHERE student_id = %s

-- Get room allocation status
SELECT room FROM student WHERE student_id = %s

3. Fee Payment

-- Check for existing pending payments
SELECT * FROM fee_payment 
WHERE student_id = %s AND payment_status = 'Pending'

-- Insert new pending payment
INSERT INTO fee_payment (student_id, amount, payment_status) VALUES (%s, %s, 'Pending')

-- Update payment status after success
UPDATE fee_payment 
SET payment_status = 'Confirmed', payment_id = %s, payment_date = %s 
WHERE student_id = %s AND amount = %s AND payment_status = 'Pending'

-- Update student's fee status
UPDATE student SET fee_status = 'Paid' WHERE student_id = %s

-- Fetch payment receipt details
SELECT amount, payment_date, payment_id FROM fee_payment 
WHERE student_id = %s AND payment_status = 'Confirmed' LIMIT 1
;

4. Room Allocation

-- Get student's gender (for hostel assignment)
SELECT gender FROM student WHERE student_id = %s

-- Find available room in eligible hostel
SELECT room_number FROM room 
WHERE hostel_name = %s AND available_space > 0 
ORDER BY room_number ASC LIMIT 1

-- Assign room to student
UPDATE student SET room = %s WHERE student_id = %s

-- Decrement room availability
UPDATE room SET available_space = available_space - 1 
WHERE room_number = %s

5. Maintenance Requests

-- Submit new request
INSERT INTO maintenance_request 
(student_id, room_number, description, request_date) 
VALUES (%s, %s, %s, NOW())


6. Leave Applications

-- Apply for leave
INSERT INTO student_leave 
(student_id, reason, start_date, return_date) 
VALUES (%s, %s, NOW(), %s)

;

 ADMIN DASHBOARD QUERIES

1. Student Management

-- Add new student
INSERT INTO student 
(student_id, name, email_id, password, date_of_birth, contact_number, gender) 
VALUES (%s, %s, %s, %s, %s, %s, %s)

-- List all students (paginated)
SELECT student_id, name, email_id, room FROM student LIMIT %s OFFSET %s

-- Search students
SELECT student_id, name, email_id, room FROM student 
WHERE student_id LIKE %s OR name LIKE %s

-- Delete student(s)
DELETE FROM student WHERE student_id = %s

-- Free up room after deletion
UPDATE room SET available_space = available_space + 1 
WHERE room_number = %s

;

2. Staff Management

-- Add staff member
INSERT INTO staff 
(staff_id, name, email_id, contact_number, hostel_name, designation, gender) 
VALUES (%s, %s, %s, %s, %s, %s, %s)

-- List all staff
SELECT staff_id, name, email_id, designation FROM staff

-- Delete staff
DELETE FROM staff WHERE staff_id = %s

;

3. Maintenance & Complaints

-- List all complaints (filter by status)
SELECT * FROM maintenance_request WHERE status = %s

-- Update complaint status
UPDATE maintenance_request SET status = %s WHERE request_id = %s

-- Delete complaints
DELETE FROM maintenance_request WHERE request_id IN (%s)

;

4. Leave Management

-- List all leave applications
SELECT sl.*, s.name FROM student_leave sl 
JOIN student s ON sl.student_id = s.student_id

-- Approve/reject leave
UPDATE student_leave SET status = %s WHERE leave_id = %s

-- Count active leave requests
SELECT COUNT(*) AS on_leave_count FROM student_leave 
WHERE status = 'On leave'

;

5. Hostel & Room Management

-- Get hostel occupancy stats
SELECT h.hostel_name, 200 - SUM(r.available_space) AS total_students 
FROM hostel h LEFT JOIN room r ON h.hostel_name = r.hostel_name 
GROUP BY h.hostel_name

-- Update hostel occupancy data
UPDATE hostel SET total_students_present = %s 
WHERE hostel_name = %s

-- List students in a specific hostel
SELECT s.student_id, s.name, s.room 
FROM student s JOIN room r ON s.room = r.room_number 
WHERE r.hostel_name = %s

;

6. View_Payments

SELECT fp.payment_id, fp.student_id, s.name, fp.amount, fp.payment_status, fp.payment_date

FROM fee_payment fp

JOIN student s ON fp.student_id = s.student_id

WHERE fp.payment_id LIKE %s OR fp.student_id LIKE %s OR s.name LIKE %s

LIMIT %s OFFSET %s

--@block
SELECT * FROM hms_db1.hostel;

--@block
ALTER TABLE hms_db1.hostel ADD COLUMN total_fee_paid INT DEFAULT 0;

--@block
UPDATE hms_db1.hostel
SET total_fee_paid = 3000
WHERE hostel_name = 'G';

--@Block
SELECT * FROM hms_db1.student ;

--@block
SELECT * FROM hms_db1.room;

--@block

UPDATE hms_db1.room SET available_space = 1 WHERE room_number = 'A100';

--@block
UPDATE hms_db1.student SET room = 'A100' WHERE student_id = 'B25102';

--@block

SELECT name, student_id FROM hms_db1.student WHERE name LIKE '%KOTI%';

--@block
DROP DATABASE hms_db1;

--@block
USE hms_db1;

--@block
SELECT * FROM hostel;

--@block
SELECT s.name, s.student_id, h.hostel_name 
FROM hostel h 
JOIN student s ON s.hostel_name = h.hostel_name;

--@block

SELECT * FROM student
WHERE name LIKE '%Amit%';

--@block
DELETE FROM maintenance_request WHERE request_id IN ('1','2','3');

--@block
SELECT COUNT(*) AS total_students
FROM student WHERE hostel_name='B';

--@block
SELECT h.hostel_name, 200 - COALESCE(SUM(r.available_space), 0) AS total_students_present
        FROM hostel h
        LEFT JOIN room r ON h.hostel_name = r.hostel_name
        GROUP BY h.hostel_name;

--@block
SELECT SUM(amount) as total_fee_collected
FROM fee_payment
WHERE payment_status='Confirmed';

--@block
DELETE FROM room
WHERE room_number='A1';