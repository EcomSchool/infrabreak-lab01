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
service vsftpd start || (echo "[!] vsftpd fallback..." && vsftpd /etc/vsftpd.conf &)

# -------- MYSQL --------
echo "[*] Starting MySQL..."
service mysql start

MAX_TRIES=30
i=0
while ! mysqladmin ping -u root --silent; do
    sleep 1
    i=$((i+1))
    [ $i -gt $MAX_TRIES ] && break
done

mysql -u root < /docker-entrypoint-initdb.d/init_mysql.sql 2>/dev/null || true

ALICE_KEY=$(cat /tmp/alice_key)
CHARLIE_KEY=$(cat /tmp/charlie_key)

mysql -u root internaldb 2>/dev/null << SQL || true
INSERT IGNORE INTO ssh_users (username, ssh_private_key, note) VALUES
('alice', '${ALICE_KEY}', 'Dev server access - decommissioned'),
('charlie', '${CHARLIE_KEY}', 'Monitoring access - active');
SQL

mysql -u root internaldb 2>/dev/null << SQL || true
INSERT IGNORE INTO internal_flags (label, value) VALUES
('stage3', 'ECOM{db_dump_succ3ssful_g00d_j0b}');
SQL

cat > /tmp/fix_user.sql << 'SQLEOF'
DROP USER IF EXISTS 'dbadmin'@'%';
CREATE USER 'dbadmin'@'%' IDENTIFIED BY 'C0rp0r4te#2024' REQUIRE NONE;
GRANT SELECT ON internaldb.* TO 'dbadmin'@'%';
FLUSH PRIVILEGES;
SQLEOF
mysql -u root < /tmp/fix_user.sql
echo "[*] MySQL ready."

# -------- POSTGRESQL --------
echo "[*] Starting PostgreSQL..."
service postgresql start
sleep 3

sudo -u postgres psql -c "CREATE USER pgadmin WITH SUPERUSER PASSWORD 'sunshine';" 2>/dev/null || \
sudo -u postgres psql -c "ALTER USER pgadmin WITH SUPERUSER PASSWORD 'sunshine';" 2>/dev/null || true

# Stage 5 flag
echo 'ECOM{rce_v1a_cve_2019_9193_pwned}' > /var/lib/postgresql/flag.txt
chown postgres:postgres /var/lib/postgresql/flag.txt
chmod 640 /var/lib/postgresql/flag.txt

echo "[*] PostgreSQL ready."

# -------- FLAG CHECKER --------
echo "[*] Starting Flag Checker on port 8088..."
cd /opt/flagchecker
python3 app.py &

echo ""
echo "=========================================="
echo "  InfraBreak: Exploitation Lab 01 — READY"
echo "=========================================="
echo "  FTP     : port 21  (anonymous login)"
echo "  SSH     : port 2222 (key-based, charlie)"
echo "  MySQL   : port 3306 (dbadmin)"
echo "  PgSQL   : port 5432 (pgadmin)"
echo "  Flags   : http://<IP>:8088"
echo "=========================================="

tail -f /dev/null
