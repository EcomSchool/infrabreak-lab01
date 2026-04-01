# ECOM Lab — CTF Challenge

A multi-stage penetration testing challenge for the ECOM Offensive Cybersecurity course.

## Build & Run

```bash
# Build the image
docker build -t ecom-lab .

# Run the container
docker run -d --name ecom-lab \
  -p 21:21 \
  -p 22:22 \
  -p 3306:3306 \
  -p 5432:5432 \
  -p 40000-40010:40000-40010 \
  ecom-lab

# Get the container's IP
docker inspect ecom-lab | grep IPAddress
```

## Challenge Objective

**Two flags to capture:**
- `flag.txt` in charlie's home directory
- `root_flag.txt` in `/root`

## Attack Surface

| Port | Service | Notes |
|------|---------|-------|
| 21   | FTP     | Anonymous login enabled |
| 22   | SSH     | Key-based auth only |
| 3306 | MySQL   | Remote connections open |
| 5432 | PostgreSQL | CVE-2019-9193 target |

## Student Instructions

1. Run an nmap scan against the target IP to identify open services
2. Explore each service and find your way to both flags
3. You will need: **john/hashcat**, **mysql client**, **Metasploit**

## Notes for Instructor

- Walkthrough is in `WALKTHROUGH.md` — keep this from students
- Zip password: `monkey1987` (mid-rockyou, takes a couple of minutes to crack)
- DB password in log: `C0rp0r4te#2024` (completely separate)
- MD5 hash in charlie's notes decodes to `redteam2024` → this is the pgadmin PostgreSQL password
- CVE-2019-9193 works when PostgreSQL user is a superuser — `pgadmin` is configured as one
- Postgres gets `sudo /bin/bash` for the privesc step
