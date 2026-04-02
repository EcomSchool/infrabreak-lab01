# =============================================
# InfraBreak: Exploitation Lab 01
# ECOM Offensive Cybersecurity Course
# Attack chain: FTP -> MySQL -> SSH -> PostgreSQL RCE -> Root
# =============================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# -------- PACKAGES --------
RUN apt-get update && apt-get install -y \
    vsftpd \
    mysql-server \
    openssh-server \
    postgresql \
    postgresql-contrib \
    zip \
    unzip \
    sudo \
    curl \
    nano \
    net-tools \
    iputils-ping \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# -------- FLASK FLAG CHECKER --------
COPY files/flagchecker/requirements.txt /opt/flagchecker/requirements.txt
RUN pip3 install -r /opt/flagchecker/requirements.txt
COPY files/flagchecker/app.py /opt/flagchecker/app.py
COPY files/flagchecker/static /opt/flagchecker/static

# -------- USERS --------
RUN useradd -m -s /bin/bash charlie && \
    useradd -m -s /bin/bash pgadmin && \
    echo "charlie:ThisIsNotTheFlag" | chpasswd && \
    echo "pgadmin:sunshine" | chpasswd && \
    usermod -aG sudo pgadmin

# Postgres gets sudo to /bin/bash (privesc path)
RUN echo "postgres ALL=(root) NOPASSWD: /bin/bash" >> /etc/sudoers

# -------- SSH SERVER --------
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# -------- FTP SETUP --------
RUN mkdir -p /var/ftp/pub/logs /var/ftp/pub/backups /var/ftp/pub/reports \
             /var/run/vsftpd/empty

COPY files/vsftpd.conf /etc/vsftpd.conf

# Stage 1 flag — visible on FTP
RUN echo 'ECOM{anon_ftp_is_a_bad_idea}' > /var/ftp/pub/flag.txt && \
    chmod 644 /var/ftp/pub/flag.txt

# Decoy FTP files
COPY files/ftp/logs/access_2024_01.log /var/ftp/pub/logs/
COPY files/ftp/logs/access_2024_02.log /var/ftp/pub/logs/
COPY files/ftp/reports/q1_summary.txt  /var/ftp/pub/reports/
COPY files/ftp/reports/q2_summary.txt  /var/ftp/pub/reports/

RUN chmod -R 755 /var/ftp/pub && chown -R nobody:nogroup /var/ftp/pub

# -------- ENCRYPTED ZIP (Stage 2 flag inside) --------
COPY files/zip_contents/ /tmp/zip_contents/
# Stage 2 flag goes inside the zip
RUN echo 'ECOM{zip_crack3d_w1th_r0cky0u}' > /tmp/zip_contents/logs/flag.txt && \
    cd /tmp/zip_contents && \
    zip -r -P monkey1987 /var/ftp/pub/backups/db_backup_march.zip logs/ && \
    rm -rf /tmp/zip_contents && \
    chown nobody:nogroup /var/ftp/pub/backups/db_backup_march.zip

# -------- MYSQL INIT --------
COPY files/init_mysql.sql /docker-entrypoint-initdb.d/init_mysql.sql
COPY files/mysql_remote.cnf /etc/mysql/mysql.conf.d/remote.cnf

# -------- CHARLIE HOME --------
# Stage 4 flag
RUN echo 'ECOM{ssh_k3y_fr0m_db_n1c3_w0rk}' > /home/charlie/flag.txt && \
    printf 'TODO: Update pgadmin service password\nCurrent hash: 0571749e2ac330a7455809c6b0e7af90\n- Service runs on port 5432\n- Check with IT before changing\n' \
        > /home/charlie/notes.txt && \
    chown charlie:charlie /home/charlie/flag.txt /home/charlie/notes.txt && \
    chmod 644 /home/charlie/flag.txt /home/charlie/notes.txt

# -------- POSTGRESQL CONFIG (baked in at build time for reliable remote access) --------
COPY files/pg_hba.conf /etc/postgresql/14/main/pg_hba.conf
RUN echo "listen_addresses = '*'" >> /etc/postgresql/14/main/postgresql.conf && \
    chown postgres:postgres /etc/postgresql/14/main/pg_hba.conf && \
    chmod 640 /etc/postgresql/14/main/pg_hba.conf

# -------- ROOT FLAG (Stage 6) --------
RUN echo 'ECOM{r00t_0wn3d_infrabreak_01_gg}' > /root/root_flag.txt && \
    chmod 600 /root/root_flag.txt

# -------- ENTRYPOINT --------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Ports: FTP, SSH, MySQL, PostgreSQL, Flag Checker webapp
EXPOSE 21 22 3306 5432 8088
EXPOSE 40000-40010

CMD ["/entrypoint.sh"]
