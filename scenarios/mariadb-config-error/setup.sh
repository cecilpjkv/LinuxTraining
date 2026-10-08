#!/bin/bash
set -e
systemctl enable --now mariadb
for i in $(seq 1 30); do mysqladmin ping >/dev/null 2>&1 </dev/null && break; sleep 1; done
mysql </dev/null -e "
CREATE DATABASE IF NOT EXISTS shopdb;
CREATE TABLE IF NOT EXISTS shopdb.products (id INT PRIMARY KEY, name VARCHAR(64), price DECIMAL(8,2));
INSERT IGNORE INTO shopdb.products VALUES (1,'Product A',9.90),(2,'Product B',19.90),(3,'Product C',29.90);
CREATE TABLE IF NOT EXISTS shopdb.orders (id INT PRIMARY KEY, product_id INT, qty INT, total DECIMAL(8,2));
INSERT IGNORE INTO shopdb.orders VALUES (1,1,2,19.80),(2,3,1,29.90),(3,2,3,59.70);
CREATE USER IF NOT EXISTS 'shopapp'@'localhost' IDENTIFIED BY 'Shop-App-Pass-1';
CREATE USER IF NOT EXISTS 'shopapp'@'127.0.0.1' IDENTIFIED BY 'Shop-App-Pass-1';
GRANT SELECT, INSERT, UPDATE, DELETE ON shopdb.* TO 'shopapp'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON shopdb.* TO 'shopapp'@'127.0.0.1';
FLUSH PRIVILEGES;"
cat > /etc/my.cnf.d/zz-tuning.cnf <<'X'
# capacity tuning (ticket 7741)
[mysqld]
max_conections = 500
X
systemctl restart mariadb || true
