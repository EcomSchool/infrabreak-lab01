#!/bin/bash
set -e

echo "[*] Starting ECOM Lab..."

# -------- SSH KEYS (generated fresh each container start) --------
echo "[*] Generating SSH keypairs..."
ssh-keygen -t rsa -b 2048 -f /tmp/alice_key -N "" -C "alice@internal" -q
ssh-keygen -t rsa -b 2048 -f /tmp/charlie_key -N "" -C "charlie@internal" -q

mkdir -p /home/charlie/.ssh
cp /tmp/charlie_key.pub /home/charlie/.ssh/authorized_keys
chown -R charlie:charlie /home/charlie/.ssh
chmod 700 /home/charlie/.ssh
chmod 600 /home/charlie/.ssh/authorized_keys

# -------- SSHD --------
echo "[*] Starting SSH daemon..."
service ssh start

# -------- FTP --------
echo "[*] Starting FTP server..."
service vsftpd start

# -------- MYSQL --------
echo "[*] Starting MySQL..."
service mysql start
sleep 3

# Init DB schema
mysql -u root < /docker-entrypoint-initdb.d/init_mysql.sql 2>/dev/null || true

# Insert SSH keys
ALICE_KEY=$(cat /tmp/alice_key)
CHARLIE_KEY=$(cat /tmp/charlie_key)

mysql -u root internaldb 2>/dev/null << SQL || true
INSERT INTO ssh_users (username, ssh_private_key, note) VALUES
('alice', '${ALICE_KEY}', 'Dev server access - decommissioned'),
('charlie', '${CHARLIE_KEY}', 'Monitoring access - active');
SQL

# Also update dbadmin password in case init ran with old value
mysql -u root 2>/dev/null << SQL2 || true
ALTER USER 'dbadmin'@'%' IDENTIFIED BY 'C0rp0r4te#2024';
FLUSH PRIVILEGES;
SQL2

echo "[*] MySQL ready."

# -------- POSTGRESQL --------
echo "[*] Starting PostgreSQL..."
service postgresql start
sleep 3

# Configure pgadmin user as superuser (needed for CVE-2019-9193 exploit)
sudo -u postgres psql -c "CREATE USER pgadmin WITH SUPERUSER PASSWORD 'redteam2024';" 2>/dev/null || \
sudo -u postgres psql -c "ALTER USER pgadmin WITH SUPERUSER PASSWORD 'redteam2024';" 2>/dev/null || true

# Allow remote connections
PG_VERSION=$(ls /etc/postgresql/ | head -1)
PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"
PG_CONF="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"

grep -q "0.0.0.0/0" "$PG_HBA" || echo "host all all 0.0.0.0/0 md5" >> "$PG_HBA"
grep -q "listen_addresses" "$PG_CONF" || echo "listen_addresses='*'" >> "$PG_CONF"

service postgresql restart
sleep 2

echo "[+] ECOM Lab is ready."
echo "    FTP  : port 21 (anonymous)"
echo "    MySQL: port 3306 (dbadmin / Welc0me2024!)"
echo "    SSH  : port 22 (charlie key from DB)"
echo "    PgSQL: port 5432 (pgadmin / sunshine95)"

# Keep container alive
tail -f /dev/null
