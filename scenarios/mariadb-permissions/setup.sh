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
mysql </dev/null -e "
CREATE USER IF NOT EXISTS 'reporting'@'localhost' IDENTIFIED BY 'Report-Pass-1';
GRANT SELECT ON shopdb.products TO 'reporting'@'localhost';
FLUSH PRIVILEGES;"
cat > /usr/local/bin/sales-report <<'X'
#!/bin/bash
# nightly sales report (read-only)
mysql -ureporting -pReport-Pass-1 shopdb -N -e "SELECT p.name, SUM(o.qty), SUM(o.total) FROM orders o JOIN products p ON p.id=o.product_id GROUP BY p.name ORDER BY p.name" </dev/null
X
chmod 755 /usr/local/bin/sales-report
