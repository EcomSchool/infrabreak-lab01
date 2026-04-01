-- ECOM Lab MySQL Init

CREATE DATABASE IF NOT EXISTS internaldb;
USE internaldb;

CREATE TABLE IF NOT EXISTS ssh_users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(64) NOT NULL,
    ssh_private_key TEXT NOT NULL,
    note VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(128),
    department VARCHAR(64),
    email VARCHAR(128),
    employee_id VARCHAR(16)
);

CREATE TABLE IF NOT EXISTS projects (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_name VARCHAR(128),
    status VARCHAR(32),
    lead VARCHAR(64)
);

INSERT INTO employees VALUES
(1,'Sarah Johnson','Engineering','sarah.j@internal.corp','EMP-1042'),
(2,'Mark Williams','DevOps','mark.w@internal.corp','EMP-1087'),
(3,'Emma Chen','Security','emma.c@internal.corp','EMP-1103'),
(4,'James Rodriguez','Networking','james.r@internal.corp','EMP-1155');

INSERT INTO projects VALUES
(1,'Network Refresh','Active','Mark Williams'),
(2,'SIEM Deployment','Planning','Emma Chen'),
(3,'DR Site Upgrade','Completed','James Rodriguez');

-- ssh_users rows are inserted by entrypoint.sh after key generation
CREATE USER IF NOT EXISTS 'dbadmin'@'%' IDENTIFIED BY 'C0rp0r4te#2024';
GRANT SELECT ON internaldb.* TO 'dbadmin'@'%';
FLUSH PRIVILEGES;
