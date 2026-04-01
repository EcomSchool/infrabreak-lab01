#!/bin/bash
set -e

echo "[*] Starting InfraBreak: Exploitation Lab 01..."

# -------- SSH KEYS --------
echo "[*] Generating SSH keypairs..."
ssh-keygen -t rsa -b 2048 -f /tmp/alice_key -N "" -C "alice@internal" -q
ssh-keygen -t rsa -b 2048 -f /tmp/charlie_key -N "" -C "charlie@internal" -q

mkdir -p /home/charlie/.ssh
cp /tmp/charlie_key.pub /home/charlie/.ssh/authorized_keys
chown -R charlie:charlie /home/charlie/.ssh
chmod 700 /home/charlie/.ssh
chmod 600 /home/charlie/.ssh/authorized_keys

# -------- SSHD --------
echo "[*] Starting SSH..."
service ssh start

# -------- FTP --------
echo "[*] Starting FTP..."
service vsftpd start || (echo "[!] vsftpd failed, trying vsftpd directly..." && vsftpd /etc/vsftpd.conf &)

# -------- MYSQL --------
echo "[*] Starting MySQL..."
# Allow remote connections in MySQL config
sed -i 's/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf 2>/dev/null || \
sed -i 's/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/my.cnf 2>/dev/null || true

service mysql start
sleep 3

# Init schema
mysql -u root < /docker-entrypoint-initdb.d/init_mysql.sql 2>/dev/null || true

# Insert SSH keys + Stage 3 flag hidden in a secrets table
ALICE_KEY=$(cat /tmp/alice_key)
CHARLIE_KEY=$(cat /tmp/charlie_key)

mysql -u root internaldb 2>/dev/null << SQL || true
INSERT IGNORE INTO ssh_users (username, ssh_private_key, note) VALUES
('alice', '${ALICE_KEY}', 'Dev server access - decommissioned'),
('charlie', '${CHARLIE_KEY}', 'Monitoring access - active');

CREATE TABLE IF NOT EXISTS internal_flags (
    id INT AUTO_INCREMENT PRIMARY KEY,
    label VARCHAR(128),
    value VARCHAR(256)
);
INSERT IGNORE INTO internal_flags (label, value) VALUES
('stage3', 'ECOM{db_dump_succ3ssful_g00d_j0b}');
SQL

# Ensure dbadmin password is correct
mysql -u root 2>/dev/null << SQL2 || true
ALTER USER 'dbadmin'@'%' IDENTIFIED BY 'C0rp0r4te#2024';
GRANT SELECT ON internaldb.* TO 'dbadmin'@'%';
FLUSH PRIVILEGES;
SQL2

echo "[*] MySQL ready."

# -------- POSTGRESQL --------
echo "[*] Starting PostgreSQL..."
service postgresql start
sleep 3

PG_VERSION=$(ls /etc/postgresql/ | head -1)
PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"
PG_CONF="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"

grep -q "0.0.0.0/0" "$PG_HBA" || echo "host all all 0.0.0.0/0 md5" >> "$PG_HBA"
grep -q "listen_addresses" "$PG_CONF" || echo "listen_addresses='*'" >> "$PG_CONF"

service postgresql restart
sleep 2

sudo -u postgres psql -c "CREATE USER pgadmin WITH SUPERUSER PASSWORD 'redteam2024';" 2>/dev/null || \
sudo -u postgres psql -c "ALTER USER pgadmin WITH SUPERUSER PASSWORD 'redteam2024';" 2>/dev/null || true

# Stage 5 flag — readable by postgres service user after RCE
echo 'ECOM{rce_v1a_cve_2019_9193_pwned}' > /var/lib/postgresql/flag.txt
chown postgres:postgres /var/lib/postgresql/flag.txt
chmod 640 /var/lib/postgresql/flag.txt

echo "[*] PostgreSQL ready."

# -------- FLAG CHECKER WEB APP --------
echo "[*] Starting Flag Checker on port 8088..."
cd /opt/flagchecker
python3 app.py &

echo ""
echo "=========================================="
echo "  InfraBreak: Exploitation Lab 01 — READY"
echo "=========================================="
echo "  FTP     : port 21  (anonymous login)"
echo "  SSH     : port 22  (key-based, charlie)"
echo "  MySQL   : port 3306"
echo "  PgSQL   : port 5432"
echo "  Flags   : http://<IP>:8088"
echo "=========================================="

# Keep container alive
tail -f /dev/null
