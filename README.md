# 🔓 InfraBreak: Exploitation Lab 01

**ECOM Offensive Cybersecurity Course — Hands-on CTF Lab**

A multi-stage penetration testing challenge where students must chain multiple attack techniques to progress from anonymous FTP access all the way to root.

---

## 🎯 Learning Objectives

By completing this lab, students will practice:
- Network scanning and service enumeration (Nmap)
- FTP anonymous login exploitation
- Offline password cracking (John the Ripper + rockyou)
- Reading and extracting credentials from log files
- MySQL remote access and database enumeration
- Extracting SSH private keys from a database
- SSH authentication with private keys
- MD5 hash cracking
- Exploiting CVE-2019-9193 (PostgreSQL RCE) with Metasploit
- Linux privilege escalation via sudo misconfiguration

---

## 🗺️ Attack Chain

```
[1] Nmap scan — discover open services
    ↓
[2] FTP anonymous login → Flag 1 + encrypted zip
    ↓
[3] Crack zip with John + rockyou → Flag 2 + DB credentials in log
    ↓
[4] MySQL login → dump tables → SSH keys + Flag 3
    ↓
[5] SSH as charlie (key from DB) → Flag 4 + hash hint
    ↓
[6] Crack MD5 hash → pgadmin credentials
    ↓
[7] Metasploit CVE-2019-9193 → RCE as postgres → Flag 5
    ↓
[8] Privilege escalation → root → Flag 6
```

---

## 🚀 Setup

### Requirements
- Docker installed on the host machine
- Port forwarding or bridged networking so students can reach the container

### Build & Run

```bash
# Clone the repo
git clone https://github.com/EcomSchool/ecom-lab.git
cd ecom-lab

# Build the image
docker build -t infrabreak-lab01 .

# Run the container
docker run -d --name infrabreak-lab01 \
  -p 21:21 \
  -p 22:22 \
  -p 3306:3306 \
  -p 5432:5432 \
  -p 8088:8088 \
  -p 40000-40010:40000-40010 \
  infrabreak-lab01
```

### Verify it's running

```bash
docker ps
docker logs infrabreak-lab01
```

### Get the target IP

If running locally:
```bash
docker inspect infrabreak-lab01 | grep IPAddress
```

If hosted on a VM, use the VM's IP address.

---

## 🌐 Services

| Port | Service | Notes |
|------|---------|-------|
| 21 | FTP | Anonymous login enabled |
| 22 | SSH | Key-based authentication only |
| 3306 | MySQL | Remote connections open |
| 5432 | PostgreSQL | CVE-2019-9193 target |
| 8088 | Flag Checker | Web UI to submit flags |

---

## 🚩 Flags

There are **6 flags** to capture, one per stage. Submit them at:

```
http://<TARGET_IP>:8088
```

All flags follow the format: `ECOM{...}`

| Stage | Where | Description |
|-------|-------|-------------|
| 1 | FTP server `/pub/flag.txt` | Reward for finding anonymous FTP |
| 2 | Inside the encrypted zip archive | Reward for cracking the zip |
| 3 | MySQL `internaldb.internal_flags` table | Reward for dumping the database |
| 4 | `/home/charlie/flag.txt` | Reward for SSH access |
| 5 | `/var/lib/postgresql/flag.txt` | Reward for RCE via CVE-2019-9193 |
| 6 | `/root/root_flag.txt` | Reward for full root access |

---

## 🛠️ Tools Needed

Students should have:
- `nmap`
- `ftp` or FileZilla
- `john` + `/usr/share/wordlists/rockyou.txt`
- `mysql` client
- `ssh`
- `hashcat` or `john`
- `metasploit` (`msfconsole`)

---

## 📋 Instructor Notes

- **WALKTHROUGH.md** contains the full solution — keep this from students
- The lab is intentionally self-contained; no internet access needed
- SSH keys are generated fresh on every container start
- Estimated completion time: 2–3 hours for motivated students
- Recommended: students work in pairs

### Credential Summary (Instructor Only)

| Service | Username | Password / Method |
|---------|---------|-------------------|
| FTP | anonymous | (any) |
| Zip | — | `monkey1987` (rockyou) |
| MySQL | `dbadmin` | `C0rp0r4te#2024` (from log) |
| SSH | `charlie` | private key from MySQL |
| Hash | — | MD5 → `redteam2024` |
| PostgreSQL | `pgadmin` | `redteam2024` |

---

## 🔄 Reset the Lab

```bash
docker stop infrabreak-lab01
docker rm infrabreak-lab01
docker run -d --name infrabreak-lab01 ... (same run command)
```

SSH keys are regenerated on each start, so students cannot reuse keys from a previous session.
