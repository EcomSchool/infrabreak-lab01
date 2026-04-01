# 🔓 InfraBreak: Exploitation Lab 01

**ECOM Offensive Cybersecurity Course — Hands-on CTF Lab**

A multi-stage penetration testing challenge where you must chain multiple attack techniques to progress from unauthenticated network access all the way to root.

---

## 🎯 Learning Objectives

By completing this lab, you will practice:
- Network scanning and service enumeration (Nmap)
- FTP anonymous login exploitation
- Offline password cracking with rockyou
- Extracting credentials from log files
- MySQL remote access and database enumeration
- SSH authentication with private keys
- Hash cracking
- Exploiting a vulnerable service using Metasploit (CVE)
- Linux privilege escalation

---

## 🗺️ Challenge Overview

The target server exposes several network services. Your goal is to **capture all 6 flags** by working through each stage of the attack chain. Each flag is hidden in a location relevant to the technique used to reach it.

Flags follow the format: `ECOM{...}`

Submit your flags at the Flag Checker web UI running on the target server at port **8088**.

---

## 🚀 Setup

### Requirements
- Docker installed on the host machine

### Build & Run

```bash
# Clone the repo
git clone https://github.com/EcomSchool/infrabreak-lab01.git
cd infrabreak-lab01

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

### Get the Target IP

```bash
# If running locally:
docker inspect infrabreak-lab01 | grep IPAddress

# If hosted on a VM, use the VM's IP address.
```

---

## 🌐 Services

| Port | Service |
|------|---------|
| 21 | FTP |
| 22 | SSH |
| 3306 | MySQL |
| 5432 | PostgreSQL |
| 8088 | Flag Checker (web UI) |

---

## 🚩 Flags

There are **6 flags** to capture — one for each stage of the attack chain.

Submit them at: `http://<TARGET_IP>:8088`

---

## 🛠️ Tools You'll Need

- `nmap`
- `ftp` client
- `john` + `rockyou.txt` wordlist
- `mysql` client
- `ssh`
- `hashcat` or `john`
- `metasploit` (`msfconsole`)

---

## 🔄 Reset the Lab

```bash
docker stop infrabreak-lab01 && docker rm infrabreak-lab01
docker run -d --name infrabreak-lab01 ... (same run command above)
```

> SSH keys are regenerated on every container start.
