#!/bin/bash
set -e
systemctl enable --now mariadb
for i in $(seq 1 30); do mysqladmin ping >/dev/null 2>&1 </dev/null && break; sleep 1; done
mysql </dev/null <<'SQL'
CREATE DATABASE IF NOT EXISTS appdb;
CREATE TABLE IF NOT EXISTS appdb.items (id INT AUTO_INCREMENT PRIMARY KEY, v VARCHAR(64));
DELETE FROM appdb.items;
INSERT INTO appdb.items (v) VALUES ('seed-1'), ('seed-2');
CREATE USER IF NOT EXISTS 'appuser'@'localhost' IDENTIFIED BY 'App-Pass-1';
GRANT SELECT, INSERT, UPDATE, DELETE ON appdb.* TO 'appuser'@'localhost';
FLUSH PRIVILEGES;
SQL
# the break: the server is read-only now and stays read-only after a restart
printf '[mysqld]\nread_only=ON\n' > /etc/my.cnf.d/zz-readonly.cnf
mysql </dev/null -e "SET GLOBAL read_only=ON"
