# =============================================
# ECOM Lab - CTF Challenge
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
    && rm -rf /var/lib/apt/lists/*

# -------- USERS --------
RUN useradd -m -s /bin/bash charlie && \
    useradd -m -s /bin/bash pgadmin && \
    echo "charlie:ThisIsNotTheFlag" | chpasswd && \
    echo "pgadmin:redteam2024" | chpasswd && \
    usermod -aG sudo pgadmin

# Give postgres user sudo access to /bin/bash (the privesc path)
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

# Decoy FTP files
COPY files/ftp/logs/access_2024_01.log /var/ftp/pub/logs/
COPY files/ftp/logs/access_2024_02.log /var/ftp/pub/logs/
COPY files/ftp/reports/q1_summary.txt  /var/ftp/pub/reports/
COPY files/ftp/reports/q2_summary.txt  /var/ftp/pub/reports/

RUN chmod -R 755 /var/ftp/pub && chown -R nobody:nogroup /var/ftp/pub

# -------- ENCRYPTED ZIP --------
COPY files/zip_contents/ /tmp/zip_contents/
RUN cd /tmp/zip_contents && \
    zip -r -P monkey1987 /var/ftp/pub/backups/db_backup_march.zip logs/ && \
    rm -rf /tmp/zip_contents && \
    chown nobody:nogroup /var/ftp/pub/backups/db_backup_march.zip

# -------- MYSQL INIT --------
COPY files/init_mysql.sql /docker-entrypoint-initdb.d/init_mysql.sql

# -------- CHARLIE HOME --------
RUN echo 'ECOM{y0u_f0und_the_s3cr3t_flag_nice_work}' > /home/charlie/flag.txt && \
    printf 'TODO: Update pgadmin service password\nCurrent hash: d5961b48a4c9b57fa289155b3e64620a\n- Service runs on port 5432\n- Check with IT before changing\n' \
        > /home/charlie/notes.txt && \
    chown charlie:charlie /home/charlie/flag.txt /home/charlie/notes.txt && \
    chmod 644 /home/charlie/flag.txt /home/charlie/notes.txt

# -------- ROOT FLAG --------
RUN echo 'ECOM{r00t_fl4g_y0u_0wn3d_th3_b0x_gg}' > /root/root_flag.txt && \
    chmod 600 /root/root_flag.txt

# -------- ENTRYPOINT --------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 21 22 3306 5432
# FTP passive ports
EXPOSE 40000-40010

CMD ["/entrypoint.sh"]
