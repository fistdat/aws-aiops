# Hướng Dẫn Cài Đặt Zabbix 7.4.5 Trên Ubuntu 22.04

## Mục Lục
1. [Giới thiệu](#giới-thiệu)
2. [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
3. [Cài đặt Dependencies](#cài-đặt-dependencies)
4. [Cài đặt và Cấu hình PostgreSQL](#cài-đặt-và-cấu-hình-postgresql)
5. [Compile Zabbix từ Source](#compile-zabbix-từ-source)
6. [Cấu hình Zabbix Server](#cấu-hình-zabbix-server)
7. [Cấu hình Zabbix Agent](#cấu-hình-zabbix-agent)
8. [Cấu hình Zabbix Proxy](#cấu-hình-zabbix-proxy)
9. [Cài đặt Web Frontend](#cài-đặt-web-frontend)
10. [Tạo Systemd Services](#tạo-systemd-services)
11. [Khắc phục sự cố](#khắc-phục-sự-cố)

---

## Giới thiệu

Tài liệu này hướng dẫn chi tiết cách cài đặt Zabbix 7.4.5 từ source code trên Ubuntu 22.04 LTS với các thành phần:
- Zabbix Server
- Zabbix Agent
- Zabbix Proxy
- Web Frontend (Nginx + PHP 8.1)
- PostgreSQL Database

## Yêu cầu hệ thống

### Phần cứng tối thiểu
- CPU: 2 cores
- RAM: 4GB
- Disk: 20GB

### Phần mềm
- Ubuntu 22.04 LTS
- PostgreSQL 14
- Nginx
- PHP 8.1

---

## Cài đặt Dependencies

### 1. Cập nhật hệ thống

```bash
sudo apt update
sudo apt upgrade -y
```

### 2. Cài đặt build tools và libraries

```bash
sudo apt install -y build-essential \
    libpcre3-dev \
    libpcre2-dev \
    libssl-dev \
    libpq-dev \
    libevent-dev \
    libsnmp-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    libssh2-1-dev \
    libldap2-dev \
    libiksemel-dev \
    libopenipmi-dev \
    libgnutls28-dev \
    unixodbc-dev \
    default-libmysqlclient-dev \
    pkg-config \
    autoconf \
    automake
```

### 3. Cài đặt PostgreSQL

```bash
sudo apt install -y postgresql postgresql-contrib
```

### 4. Cài đặt Nginx và PHP

```bash
sudo apt install -y nginx \
    php-fpm \
    php-pgsql \
    php-mbstring \
    php-gd \
    php-xml \
    php-bcmath \
    php-ldap \
    php-curl
```

---

## Cài đặt và Cấu hình PostgreSQL

### 1. Tạo user và databases

```bash
# Tạo user zabbix
sudo -u postgres psql -c "CREATE USER zabbix WITH PASSWORD 'zabbix123';"

# Tạo database cho Server
sudo -u postgres psql -c "CREATE DATABASE zabbix OWNER zabbix;"

# Tạo database cho Proxy
sudo -u postgres psql -c "CREATE DATABASE zabbix_proxy OWNER zabbix;"
```

**Lưu ý quan trọng**: Database cho server phải là `zabbix` để khớp với cấu hình frontend.

### 2. Import schema và data

Giả sử bạn đã giải nén Zabbix source vào `/home/sysadmin/2025/aismc/zabbix-7.4.5`:

```bash
cd /home/sysadmin/2025/aismc/zabbix-7.4.5

# Import schema cho Server
sudo -u postgres psql zabbix < database/postgresql/schema.sql

# Import images
sudo -u postgres psql zabbix < database/postgresql/images.sql

# Import data
sudo -u postgres psql zabbix < database/postgresql/data.sql

# Import schema cho Proxy
sudo -u postgres psql zabbix_proxy < database/postgresql/schema.sql
```

### 3. Cấp quyền cho user zabbix

```bash
sudo -u postgres psql -d zabbix -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO zabbix;"
sudo -u postgres psql -d zabbix -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO zabbix;"
sudo -u postgres psql -d zabbix -c "GRANT ALL PRIVILEGES ON DATABASE zabbix TO zabbix;"

sudo -u postgres psql -d zabbix_proxy -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO zabbix;"
sudo -u postgres psql -d zabbix_proxy -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO zabbix;"
sudo -u postgres psql -d zabbix_proxy -c "GRANT ALL PRIVILEGES ON DATABASE zabbix_proxy TO zabbix;"
```

---

## Compile Zabbix từ Source

### 1. Giải nén source code

```bash
cd /home/sysadmin/2025/aismc
tar -xzf zabbix/zabbix-7.4.5.tar.gz
cd zabbix-7.4.5
```

### 2. Tạo user và group cho Zabbix

```bash
sudo groupadd --system zabbix
sudo useradd --system -g zabbix -d /usr/lib/zabbix -s /sbin/nologin -c "Zabbix Monitoring System" zabbix
```

### 3. Configure

```bash
./configure \
    --enable-server \
    --enable-agent \
    --enable-proxy \
    --with-postgresql \
    --with-net-snmp \
    --with-libcurl \
    --with-libxml2 \
    --with-ssh2 \
    --with-openipmi \
    --with-ldap
```

### 4. Compile và cài đặt

```bash
make -j$(nproc)
sudo make install
```

### 5. Tạo thư mục cần thiết

```bash
sudo mkdir -p /var/log/zabbix
sudo mkdir -p /var/run/zabbix
sudo mkdir -p /usr/local/share/zabbix/alertscripts
sudo mkdir -p /usr/local/share/zabbix/externalscripts

sudo chown -R zabbix:zabbix /var/log/zabbix
sudo chown -R zabbix:zabbix /var/run/zabbix
sudo chown -R zabbix:zabbix /usr/local/share/zabbix
```

---

## Cấu hình Zabbix Server

### 1. Tạo file cấu hình

```bash
sudo nano /usr/local/etc/zabbix_server.conf
```

Nội dung:

```ini
LogFile=/var/log/zabbix/zabbix_server.log
DBHost=localhost
DBName=zabbix
DBUser=zabbix
DBPassword=zabbix123
PidFile=/run/zabbix/zabbix_server.pid
AlertScriptsPath=/usr/local/share/zabbix/alertscripts
ExternalScripts=/usr/local/share/zabbix/externalscripts

# High Availability (optional cho standalone server)
#HANodeName=zabbix-server-main
#NodeAddress=localhost:10051
```

**Lưu ý**:
- `DBName` phải là `zabbix` để khớp với frontend
- HA configuration có thể bật nếu cần chế độ High Availability

### 2. Set quyền

```bash
sudo chown zabbix:zabbix /usr/local/etc/zabbix_server.conf
sudo chmod 640 /usr/local/etc/zabbix_server.conf
```

---

## Cấu hình Zabbix Agent

### 1. Tạo file cấu hình

```bash
sudo nano /usr/local/etc/zabbix_agentd.conf
```

Nội dung:

```ini
LogFile=/var/log/zabbix/zabbix_agentd.log
Server=127.0.0.1
ServerActive=127.0.0.1
Hostname=Zabbix server
PidFile=/run/zabbix/zabbix_agentd.pid
```

### 2. Set quyền

```bash
sudo chown zabbix:zabbix /usr/local/etc/zabbix_agentd.conf
sudo chmod 640 /usr/local/etc/zabbix_agentd.conf
```

---

## Cấu hình Zabbix Proxy

### 1. Tạo file cấu hình

```bash
sudo nano /usr/local/etc/zabbix_proxy.conf
```

Nội dung:

```ini
LogFile=/var/log/zabbix/zabbix_proxy.log
DBHost=localhost
DBName=zabbix_proxy
DBUser=zabbix
DBPassword=zabbix123
Server=127.0.0.1
Hostname=Zabbix proxy
PidFile=/run/zabbix/zabbix_proxy.pid
ConfigFrequency=3600
```

### 2. Set quyền

```bash
sudo chown zabbix:zabbix /usr/local/etc/zabbix_proxy.conf
sudo chmod 640 /usr/local/etc/zabbix_proxy.conf
```

---

## Cài đặt Web Frontend

### 1. Copy frontend files

```bash
cd /home/sysadmin/2025/aismc/zabbix-7.4.5
sudo mkdir -p /usr/share/zabbix
sudo cp -r ui/* /usr/share/zabbix/
sudo chown -R www-data:www-data /usr/share/zabbix
```

### 2. Cấu hình PHP

```bash
sudo nano /etc/php/8.1/fpm/php.ini
```

Sửa các dòng sau:

```ini
max_execution_time = 300
max_input_time = 300
memory_limit = 128M
post_max_size = 16M
upload_max_filesize = 2M
date.timezone = Asia/Ho_Chi_Minh
```

Restart PHP-FPM:

```bash
sudo systemctl restart php8.1-fpm
```

### 3. Cấu hình Nginx

```bash
sudo nano /etc/nginx/sites-available/zabbix.conf
```

Nội dung:

```nginx
server {
    listen 8080;
    server_name _;

    root /usr/share/zabbix;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

**Lưu ý**: Port 8080 được sử dụng nếu port 80 bị chiếm bởi service khác.

### 4. Enable site và restart Nginx

```bash
sudo ln -s /etc/nginx/sites-available/zabbix.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

---

## Tạo Systemd Services

### 1. Zabbix Server Service

```bash
sudo nano /etc/systemd/system/zabbix-server.service
```

Nội dung:

```ini
[Unit]
Description=Zabbix Server
After=syslog.target network.target postgresql.service

[Service]
Type=forking
User=zabbix
Group=zabbix
RuntimeDirectory=zabbix
RuntimeDirectoryMode=0755
PIDFile=/run/zabbix/zabbix_server.pid
ExecStart=/usr/local/sbin/zabbix_server -c /usr/local/etc/zabbix_server.conf
ExecStop=/bin/kill -SIGTERM $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### 2. Zabbix Agent Service

```bash
sudo nano /etc/systemd/system/zabbix-agent.service
```

Nội dung:

```ini
[Unit]
Description=Zabbix Agent
After=syslog.target network.target

[Service]
Type=forking
User=zabbix
Group=zabbix
RuntimeDirectory=zabbix
RuntimeDirectoryMode=0755
PIDFile=/run/zabbix/zabbix_agentd.pid
ExecStart=/usr/local/sbin/zabbix_agentd -c /usr/local/etc/zabbix_agentd.conf
ExecStop=/bin/kill -SIGTERM $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### 3. Zabbix Proxy Service

```bash
sudo nano /etc/systemd/system/zabbix-proxy.service
```

Nội dung:

```ini
[Unit]
Description=Zabbix Proxy
After=syslog.target network.target postgresql.service

[Service]
Type=forking
User=zabbix
Group=zabbix
RuntimeDirectory=zabbix
RuntimeDirectoryMode=0755
PIDFile=/run/zabbix/zabbix_proxy.pid
ExecStart=/usr/local/sbin/zabbix_proxy -c /usr/local/etc/zabbix_proxy.conf
ExecStop=/bin/kill -SIGTERM $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### 4. Reload systemd và enable services

```bash
sudo systemctl daemon-reload
sudo systemctl enable zabbix-server
sudo systemctl enable zabbix-agent
sudo systemctl enable zabbix-proxy
```

### 5. Khởi động services

```bash
# Khởi động bằng lệnh trực tiếp (recommended để tránh lỗi systemd)
sudo -u zabbix /usr/local/sbin/zabbix_server -c /usr/local/etc/zabbix_server.conf
sudo -u zabbix /usr/local/sbin/zabbix_agentd -c /usr/local/etc/zabbix_agentd.conf
sudo -u zabbix /usr/local/sbin/zabbix_proxy -c /usr/local/etc/zabbix_proxy.conf

# Hoặc dùng systemctl (có thể gặp lỗi PID file)
sudo systemctl start zabbix-server
sudo systemctl start zabbix-agent
sudo systemctl start zabbix-proxy
```

### 6. Kiểm tra trạng thái

```bash
sudo systemctl status zabbix-server
sudo systemctl status zabbix-agent
sudo systemctl status zabbix-proxy

# Kiểm tra process
ps aux | grep zabbix
```

---

## Cấu hình Web Interface

### 1. Truy cập Web Interface

Mở trình duyệt và truy cập:

```
http://<IP-của-server>:8080
```

Ví dụ: `http://192.168.1.22:8080`

### 2. Setup wizard

#### Bước 1: Check pre-requisites
- Tất cả các check phải hiển thị **OK**
- Nếu có lỗi, sửa file `/etc/php/8.1/fpm/php.ini` và restart PHP-FPM

#### Bước 2: Configure DB connection
```
Database type: PostgreSQL
Database host: localhost (hoặc 127.0.0.1)
Database port: 5432
Database name: zabbix
User: zabbix
Password: zabbix123
Database schema: để trống hoặc public
```

**Quan trọng**: Database name phải là `zabbix` để khớp với server configuration.

#### Bước 3: Zabbix server details
```
Host: localhost
Port: 10051
Name: Zabbix server (hoặc tên tùy chọn)
```

#### Bước 4: GUI settings
```
Default time zone: Asia/Ho_Chi_Minh
Default theme: Blue (hoặc chọn theme khác)
```

#### Bước 5: Pre-installation summary
- Review thông tin
- Click **Next step**

#### Bước 6: Install
- Click **Finish**

### 3. Đăng nhập

```
Username: Admin
Password: zabbix
```

**Lưu ý**: Username có chữ A viết hoa.

---

## Khắc phục sự cố

### 1. Lỗi kết nối database

**Triệu chứng**: "Cannot connect to the database"

**Giải pháp**:

```bash
# Kiểm tra PostgreSQL đang chạy
sudo systemctl status postgresql

# Test kết nối
PGPASSWORD=zabbix123 psql -h localhost -U zabbix -d zabbix -c "SELECT version();"

# Kiểm tra pg_hba.conf
sudo nano /etc/postgresql/14/main/pg_hba.conf

# Đảm bảo có dòng:
# host    all             all             127.0.0.1/32            scram-sha-256

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### 2. Lỗi PHP max_input_time

**Triệu chứng**: Fail ở bước check pre-requisites

**Giải pháp**:

```bash
sudo sed -i 's/^max_input_time = .*/max_input_time = 300/' /etc/php/8.1/fpm/php.ini
sudo systemctl restart php8.1-fpm
```

### 3. Lỗi Nginx port 80 bị chiếm

**Triệu chứng**: "nginx: [emerg] bind() to 0.0.0.0:80 failed"

**Giải pháp**:

```bash
# Kiểm tra process đang dùng port 80
sudo lsof -i :80

# Thay đổi port trong config Nginx
sudo nano /etc/nginx/sites-available/zabbix.conf
# Đổi "listen 80;" thành "listen 8080;"

sudo systemctl restart nginx
```

### 4. Zabbix Server không khởi động

**Triệu chứng**: Service failed hoặc không có process

**Giải pháp**:

```bash
# Kiểm tra log
sudo tail -f /var/log/zabbix/zabbix_server.log

# Chạy thủ công để xem lỗi
sudo -u zabbix /usr/local/sbin/zabbix_server -c /usr/local/etc/zabbix_server.conf

# Kiểm tra quyền thư mục
sudo chown -R zabbix:zabbix /var/log/zabbix
sudo chown -R zabbix:zabbix /var/run/zabbix
```

### 5. Permission denied cho table dbversion

**Triệu chứng**: "permission denied for table dbversion"

**Giải pháp**:

```bash
sudo -u postgres psql -d zabbix -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO zabbix;"
sudo -u postgres psql -d zabbix -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO zabbix;"
```

### 6. Lỗi "Zabbix server is running: No" trên Dashboard

**Triệu chứng**: Dashboard hiển thị "Zabbix server is running: No" mặc dù server đang chạy

**Nguyên nhân**: Database không khớp giữa Zabbix Server và Frontend
- Server config sử dụng database `zabbix_server`
- Frontend config sử dụng database `zabbix`
- HA manager ghi vào table `ha_node` trong database server đang dùng
- Frontend kiểm tra table `ha_node` trong database mà nó cấu hình

**Giải pháp**:

#### Cách 1: Thay đổi server config (Khuyến nghị)

```bash
# Sửa config server
sudo nano /usr/local/etc/zabbix_server.conf

# Đổi dòng:
# DBName=zabbix_server
# thành:
# DBName=zabbix

# Restart server
sudo systemctl restart zabbix-server

# Verify HA node registration
PGPASSWORD=zabbix123 psql -h localhost -U zabbix -d zabbix -c "SELECT * FROM ha_node;"

# Kết quả phải hiển thị server node với status = 3 (ACTIVE)
```

#### Cách 2: Thay đổi frontend config

```bash
# Sửa config frontend
sudo nano /usr/share/zabbix/conf/zabbix.conf.php

# Đổi:
# $DB['DATABASE'] = 'zabbix';
# thành:
# $DB['DATABASE'] = 'zabbix_server';

# Restart PHP-FPM
sudo systemctl restart php8.1-fpm
```

**Kiểm tra sau khi fix**:

```bash
# Kiểm tra HA node table
PGPASSWORD=zabbix123 psql -h localhost -U zabbix -d zabbix -c "SELECT *, EXTRACT(EPOCH FROM NOW())::integer - lastaccess as age_seconds FROM ha_node;"

# age_seconds phải nhỏ (< 10 giây), chứng tỏ server đang update thường xuyên
# status phải là 3 (ZBX_NODE_STATUS_ACTIVE)

# Restart PHP cache
sudo systemctl restart php8.1-fpm

# Truy cập dashboard và kiểm tra status
```

### 7. Kiểm tra log files

```bash
# Zabbix Server log
sudo tail -f /var/log/zabbix/zabbix_server.log

# Zabbix Agent log
sudo tail -f /var/log/zabbix/zabbix_agentd.log

# Zabbix Proxy log
sudo tail -f /var/log/zabbix/zabbix_proxy.log

# Nginx error log
sudo tail -f /var/log/nginx/error.log

# PostgreSQL log
sudo tail -f /var/log/postgresql/postgresql-14-main.log
```

---

## Các lệnh hữu ích

### Quản lý Services

```bash
# Restart tất cả Zabbix services
sudo systemctl restart zabbix-server zabbix-agent zabbix-proxy

# Kiểm tra status
sudo systemctl status zabbix-server zabbix-agent zabbix-proxy nginx postgresql php8.1-fpm

# Stop services
sudo systemctl stop zabbix-server zabbix-agent zabbix-proxy

# View logs realtime
sudo journalctl -u zabbix-server -f
```

### Database Management

```bash
# Backup database
sudo -u postgres pg_dump zabbix_server > zabbix_backup_$(date +%Y%m%d).sql

# Restore database
sudo -u postgres psql zabbix_server < zabbix_backup_20251122.sql

# Kiểm tra kích thước database
sudo -u postgres psql -c "SELECT pg_size_pretty(pg_database_size('zabbix_server'));"
```

### Kiểm tra version

```bash
# Zabbix Server version
/usr/local/sbin/zabbix_server -V

# Zabbix Agent version
/usr/local/sbin/zabbix_agentd -V

# Database version
sudo -u postgres psql zabbix_server -c "SELECT * FROM dbversion;"
```

---

## Bảo mật

### 1. Đổi mật khẩu Admin

Sau khi đăng nhập lần đầu, đổi mật khẩu ngay:
- Administration → Users → Admin → Password

### 2. Đổi mật khẩu database

```bash
sudo -u postgres psql -c "ALTER USER zabbix WITH PASSWORD 'new_strong_password';"

# Cập nhật trong config files
sudo nano /usr/local/etc/zabbix_server.conf
sudo nano /usr/local/etc/zabbix_proxy.conf

# Restart services
sudo systemctl restart zabbix-server zabbix-proxy
```

### 3. Firewall

```bash
# Cho phép port 8080 (Web interface)
sudo ufw allow 8080/tcp

# Cho phép port 10051 (Zabbix Server)
sudo ufw allow 10051/tcp

# Cho phép port 10050 (Zabbix Agent)
sudo ufw allow 10050/tcp
```

### 4. SSL/TLS cho Nginx

```bash
# Cài đặt certbot
sudo apt install certbot python3-certbot-nginx

# Lấy SSL certificate
sudo certbot --nginx -d your-domain.com

# Auto-renew
sudo certbot renew --dry-run
```

---

## Tài liệu tham khảo

- [Zabbix Official Documentation](https://www.zabbix.com/documentation/7.0/en/manual)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Nginx Documentation](https://nginx.org/en/docs/)

---

## Thông tin phiên bản

- **Zabbix**: 7.4.5
- **Ubuntu**: 22.04 LTS
- **PostgreSQL**: 14
- **PHP**: 8.1
- **Nginx**: 1.18

---

## Ghi chú

1. Tài liệu này được tạo dựa trên quá trình cài đặt thực tế trên Ubuntu 22.04
2. Một số đường dẫn và cấu hình có thể cần điều chỉnh tùy theo môi trường
3. Nên backup database thường xuyên
4. Nên sử dụng SSL/TLS cho production environment
5. Thay đổi mật khẩu mặc định sau khi cài đặt

---

**Tác giả**: AI Assistant
**Ngày tạo**: 2025-11-22
**Phiên bản**: 1.0
