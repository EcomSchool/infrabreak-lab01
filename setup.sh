#!/bin/bash
# =============================================
# ECOM LAB - Full Setup Script
# =============================================
set -e

# -------- USERS --------
useradd -m -s /bin/bash charlie
useradd -m -s /bin/bash pgadmin
echo "charlie:ThisIsNotTheFlag" | chpasswd
echo "pgadmin:sunshine95" | chpasswd
usermod -aG sudo pgadmin

# -------- FTP (vsftpd) --------
echo "ftp:x:14:50:FTP User:/var/ftp:/sbin/nologin" >> /etc/passwd || true

mkdir -p /var/ftp/pub/logs
mkdir -p /var/ftp/pub/backups
mkdir -p /var/ftp/pub/reports

# Log files (decoys)
cat > /var/ftp/pub/logs/access_2024_01.log << 'LOG'
2024-01-14 08:12:33 INFO  [web] GET /dashboard 200 user=admin
2024-01-14 08:15:44 INFO  [web] GET /api/users 200 user=admin
2024-01-14 09:01:02 INFO  [db] Connection from 10.0.0.5 user=webuser
2024-01-14 10:22:11 WARN  [db] Slow query detected (2.3s)
2024-01-14 11:45:00 INFO  [cron] Backup started
LOG

cat > /var/ftp/pub/logs/access_2024_02.log << 'LOG'
2024-02-01 07:00:00 INFO  [web] Server started
2024-02-01 09:12:55 INFO  [web] GET /login 200
2024-02-01 09:13:01 INFO  [auth] Login success user=admin
2024-02-01 14:00:00 INFO  [cron] Backup completed
2024-02-02 08:05:44 WARN  [db] Max connections reached
LOG

# The JUICY log (inside the encrypted zip)
mkdir -p /tmp/zipcontents/logs

cat > /tmp/zipcontents/logs/db_maintenance_2024_03.log << 'DBLOG'
2024-03-05 02:00:00 INFO  [maintenance] Starting scheduled DB maintenance
2024-03-05 02:00:01 INFO  [db] Connecting to database...
2024-03-05 02:00:01 DEBUG [db] Connection string: host=127.0.0.1 port=3306 user=dbadmin password=Welc0me2024! database=internaldb
2024-03-05 02:00:03 INFO  [db] Connection successful
2024-03-05 02:01:44 INFO  [db] Running vacuum on table users... done
2024-03-05 02:03:10 INFO  [db] Running vacuum on table sessions... done
2024-03-05 02:04:55 INFO  [db] Maintenance complete. Disconnecting.
2024-03-05 02:04:55 INFO  [maintenance] Job finished successfully
DBLOG

cat > /tmp/zipcontents/logs/error_2024_03.log << 'ERRLOG'
2024-03-01 12:44:01 ERROR [web] Unhandled exception in /api/report
2024-03-02 09:22:11 ERROR [db] Deadlock detected, retrying...
2024-03-03 15:00:00 ERROR [auth] Failed login for user admin from 203.0.113.44 - lockout triggered
ERRLOG

# Create the encrypted zip (password is from rockyou: sunshine95)
cd /tmp/zipcontents
zip -r -P sunshine95 /var/ftp/pub/backups/db_backup_march.zip logs/
cd /

# Decoy files in reports
cat > /var/ftp/pub/reports/q1_summary.txt << 'TXT'
Q1 2024 Quarterly Infrastructure Report
========================================
Servers online: 12
Incidents: 3 (all resolved)
Uptime: 99.7%
TXT

cat > /var/ftp/pub/reports/q2_summary.txt << 'TXT'
Q2 2024 Quarterly Infrastructure Report
========================================
Servers online: 14
Incidents: 1 (patched)
Uptime: 99.9%
TXT

# Set FTP permissions
chmod -R 755 /var/ftp/pub
chown -R ftp:ftp /var/ftp/pub 2>/dev/null || chown -R nobody:nogroup /var/ftp/pub

# Configure vsftpd
cat > /etc/vsftpd.conf << 'VSFTPD'
listen=YES
listen_ipv6=NO
anonymous_enable=YES
local_enable=NO
write_enable=NO
anon_root=/var/ftp
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
VSFTPD

mkdir -p /var/run/vsftpd/empty

# -------- MYSQL --------
service mysql start || mysqld_safe &
sleep 3

mysql << 'SQL'
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
    project_lead VARCHAR(64)
);

CREATE TABLE IF NOT EXISTS internal_flags (
    id INT AUTO_INCREMENT PRIMARY KEY,
    label VARCHAR(128),
    value VARCHAR(256)
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

INSERT IGNORE INTO internal_flags (label, value) VALUES
('stage3', 'ECOM{db_dump_succ3ssful_g00d_j0b}');

CREATE USER IF NOT EXISTS 'dbadmin'@'%' IDENTIFIED BY 'Welc0me2024!';
GRANT SELECT ON internaldb.* TO 'dbadmin'@'%';
FLUSH PRIVILEGES;
SQL

# -------- SSH KEYS --------
# Generate Alice key (decoy — wrong user)
ssh-keygen -t rsa -b 2048 -f /tmp/alice_key -N "" -C "alice@internal"
# Generate Charlie key (correct — grants access)
ssh-keygen -t rsa -b 2048 -f /tmp/charlie_key -N "" -C "charlie@internal"

# Set up charlie's SSH authorized keys
mkdir -p /home/charlie/.ssh
cp /tmp/charlie_key.pub /home/charlie/.ssh/authorized_keys
chown -R charlie:charlie /home/charlie/.ssh
chmod 700 /home/charlie/.ssh
chmod 600 /home/charlie/.ssh/authorized_keys

# Insert keys into DB
ALICE_KEY=$(cat /tmp/alice_key)
CHARLIE_KEY=$(cat /tmp/charlie_key)

mysql internaldb << SQL
INSERT INTO ssh_users (username, ssh_private_key, note) VALUES
('alice', '$ALICE_KEY', 'Dev server access - decommissioned'),
('charlie', '$CHARLIE_KEY', 'Monitoring access - active');
SQL

# -------- CHARLIE HOME --------
mkdir -p /home/charlie
chown charlie:charlie /home/charlie

# Flag 1
cat > /home/charlie/flag.txt << 'FLAG'
ECOM{y0u_f0und_the_s3cr3t_flag_nice_work}
FLAG
chmod 644 /home/charlie/flag.txt

# Hash hint — MD5 of "sunshine95" (same as zip password — teaches password reuse)
cat > /home/charlie/notes.txt << 'NOTES'
TODO: Update pgadmin service password
Current hash: 3a6d42c88c2b5f1a7dfe23c4b89a0e7f
- Service runs on port 5432
- Check with IT before changing
NOTES
chmod 644 /home/charlie/notes.txt

# -------- POSTGRESQL (vulnerable to CVE-2019-9193) --------
service postgresql start || pg_ctlcluster 14 main start &
sleep 3

sudo -u postgres psql << 'PGSQL'
ALTER USER pgadmin WITH PASSWORD 'sunshine95';
ALTER USER pgadmin WITH SUPERUSER;
PGSQL

# -------- FLAG 2 (root) --------
cat > /root/root_flag.txt << 'FLAG'
ECOM{r00t_fl4g_y0u_0wn3d_th3_b0x_gg}
FLAG
chmod 600 /root/root_flag.txt

echo "[+] Lab setup complete."
