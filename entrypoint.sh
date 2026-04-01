#!/bin/bash
set -e

echo "[*] Starting InfraBreak: Exploitation Lab 01..."

# ---------------------------------------------------------
# 1. SSH SETUP
# ---------------------------------------------------------
echo "[*] Generating SSH keypairs..."
ssh-keygen -A
echo "[*] Starting SSH..."
service ssh start

# ---------------------------------------------------------
# 2. FTP SETUP
# ---------------------------------------------------------
echo "[*] Starting FTP..."
service vsftpd start || {
    echo "[!] vsftpd failed, trying vsftpd directly..."
    vsftpd &
}

# ---------------------------------------------------------
# 3. MYSQL / MARIADB SETUP (Networking + Permissions)
# ---------------------------------------------------------
echo "[*] Starting MySQL..."
# Force MySQL to listen on all interfaces (Fixes Error 115)
sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null || true
sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/my.cnf 2>/dev/null || true

service mysql start

# Configure User for Remote Access and Disable SSL (Fixes Error 1130 & 2026)
mysql -e "CREATE USER IF NOT EXISTS 'dbadmin'@'%' IDENTIFIED BY 'C0rp0r4te#2024';"
mysql -e "GRANT ALL PRIVILEGES ON internaldb.* TO 'dbadmin'@'%' WITH GRANT OPTION;"
mysql -e "ALTER USER 'dbadmin'@'%' REQUIRE NONE;"
mysql -e "FLUSH PRIVILEGES;"
echo "[*] MySQL ready."

# ---------------------------------------------------------
# 4. POSTGRESQL SETUP (Networking + Permissions)
# ---------------------------------------------------------
echo "[*] Starting PostgreSQL..."
# Allow Postgres to listen on all interfaces
echo "listen_addresses = '*'" >> /etc/postgresql/14/main/postgresql.conf
# Allow remote connections in the HBA config
echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/14/main/pg_hba.conf

service postgresql start

# Ensure user exists with correct password
su - postgres -c "psql -c \"ALTER USER pgadmin WITH PASSWORD 'C0rp0r4te#2024';\"" || \
su - postgres -c "psql -c \"CREATE USER pgadmin WITH PASSWORD 'C0rp0r4te#2024';\""
echo "[*] PostgreSQL ready."

# ---------------------------------------------------------
# 5. WEB APP / FLAG CHECKER
# ---------------------------------------------------------
echo "[*] Starting Flag Checker on port 8088..."
cd /app

cat <<EOF

==========================================
  InfraBreak: Exploitation Lab 01 — READY
==========================================
  FTP     : port 21  (anonymous login)
  SSH     : port 22  (key-based, charlie)
  MySQL   : port 3306
  PgSQL   : port 5432
  Flags   : http://<IP>:8088
==========================================
EOF

# Run the Flask app as the foreground process
exec python3 app.py
