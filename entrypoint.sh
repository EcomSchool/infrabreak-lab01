#!/bin/bash
set -e

echo "[*] Starting InfraBreak: Exploitation Lab 01..."

# 1. SSH SETUP
service ssh start

# 2. FTP SETUP
service vsftpd start || vsftpd &

# 3. MYSQL SETUP
sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null || true
service mysql start
mysql -e "CREATE USER IF NOT EXISTS 'dbadmin'@'%' IDENTIFIED BY 'C0rp0r4te#2024';"
mysql -e "GRANT ALL PRIVILEGES ON internaldb.* TO 'dbadmin'@'%' WITH GRANT OPTION;"
mysql -e "ALTER USER 'dbadmin'@'%' REQUIRE NONE;"
mysql -e "FLUSH PRIVILEGES;"
echo "[*] MySQL ready."

# ---------------------------------------------------------
# 4. POSTGRESQL SETUP
# ---------------------------------------------------------
echo "[*] Starting PostgreSQL..."
# Configure Networking
echo "listen_addresses = '*'" >> /etc/postgresql/14/main/postgresql.conf
echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/14/main/pg_hba.conf

service postgresql start

# Force the password update as the 'postgres' superuser
# We use LOGIN and NOSUPERUSER to ensure it's a standard lab user
su - postgres -c "psql -c \"DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'pgadmin') THEN CREATE ROLE pgadmin WITH LOGIN PASSWORD 'C0rp0r4te#2024'; END IF; END \$\$;\""
su - postgres -c "psql -c \"ALTER ROLE pgadmin WITH LOGIN PASSWORD 'C0rp0r4te#2024';\""
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE internaldb TO pgadmin;\""

echo "[*] PostgreSQL ready."

# 5. START APP
echo "[*] Starting Flag Checker..."
# Change this to the actual path where app.py sits. 
# Based on your repo, it's the root directory.
cd / 

# Use 'nohup' so the script doesn't crash if the python app fails
nohup python3 app.py > /var/log/app.log 2>&1 &

echo "=========================================="
echo "  InfraBreak: Lab 01 is now LIVE"
echo "=========================================="

# KEEP ALIVE: This prevents the container from exiting
tail -f /dev/null
