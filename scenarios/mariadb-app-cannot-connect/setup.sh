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
mkdir -p /srv/www/shop
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test' >> /etc/hosts
mkdir -p /srv/www/shop
cat > /srv/www/shop/index.php <<'PHP'
<?php echo "<h1>Example Shop</h1><p>PHP-OK-" . (40 + 2) . "</p>\n";
PHP
cat > /etc/nginx/conf.d/shop.conf <<'CONF'
server {
    listen 80;
    server_name shop.example.test;
    root /srv/www/shop;
    index index.php;
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
CONF
cat > /srv/www/shop/config.php <<'PHP'
<?php
$DB_HOST = 'localhost';
$DB_USER = 'shopapp';
$DB_PASS = 'Shop-App-Pass-1';
$DB_NAME = 'shopdb';
PHP
cat > /srv/www/shop/index.php <<'PHP'
<?php
require __DIR__ . '/config.php';
mysqli_report(MYSQLI_REPORT_OFF);
$db = @new mysqli($DB_HOST, $DB_USER, $DB_PASS, $DB_NAME);
if ($db->connect_errno) {
    http_response_code(500);
    error_log("shop: database connection failed: " . $db->connect_error);
    echo "<h1>Example Shop</h1><p>Database connection failed</p>";
    exit;
}
echo "<h1>Example Shop</h1><ul>";
foreach ($db->query("SELECT name FROM products ORDER BY id") as $r) echo "<li>" . htmlspecialchars($r['name']) . "</li>";
echo "</ul><p>PHP-OK-" . (40 + 2) . "</p>\n";
PHP
systemctl enable --now php-fpm nginx
for i in $(seq 1 20); do [ -S /run/php-fpm/www.sock ] && break; sleep 0.5; done
curl -s -o /dev/null -H 'Host: shop.example.test' http://127.0.0.1/
cat > /etc/my.cnf.d/zz-standard.cnf <<'X'
# infrastructure standard: runtime files under /run
[mysqld]
socket = /run/mariadb/mariadb.sock
X
systemctl restart mariadb
curl -s -o /dev/null -H 'Host: shop.example.test' http://127.0.0.1/
