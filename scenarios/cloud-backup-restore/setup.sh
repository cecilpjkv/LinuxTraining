#!/bin/bash
set -e
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test test.shop.example.test' >> /etc/hosts
systemctl enable --now mariadb
for i in $(seq 1 30); do mysqladmin ping >/dev/null 2>&1 </dev/null && break; sleep 1; done
mysql </dev/null -e "CREATE DATABASE IF NOT EXISTS shop; CREATE USER IF NOT EXISTS 'shop'@'localhost' IDENTIFIED BY 'Shop-Db-Pass-4'; GRANT ALL ON shop.* TO 'shop'@'localhost';
  CREATE TABLE shop.products (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100) NOT NULL, image VARCHAR(200));
  INSERT INTO shop.products (name, image) VALUES ('Sourdough Loaf', 'sourdough.txt'), ('Apple Pie', 'apple-pie.txt'), ('Croissant', 'croissant.txt');"
A=/srv/www/shop
mkdir -p $A/images $A/docs
cat > $A/config.php <<'PHP'
<?php
$db_host = 'localhost'; $db_name = 'shop'; $db_user = 'shop'; $db_pass = 'Shop-Db-Pass-4';
PHP
cat > $A/index.php <<'PHP'
<?php
require __DIR__ . '/config.php';
$db = new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($db->connect_errno) { http_response_code(500); exit("Database error"); }
echo "<h1>Example Bakery Shop</h1><p>Database: " . htmlspecialchars($db_name) . "</p><ul>";
foreach ($db->query("SELECT name, image FROM products ORDER BY id") as $r) {
    $img = is_file(__DIR__ . '/images/' . $r['image']) ? '' : ' (image missing)';
    echo "<li>" . htmlspecialchars($r['name']) . $img . "</li>";
}
echo "</ul><p>Shop OK</p>";
PHP
for p in sourdough apple-pie croissant; do echo "image of $p" > $A/images/$p.txt; done
head -c 3M /dev/urandom > $A/docs/catalog-2026.pdf
cat > /usr/local/bin/shop-admin <<'SH'
#!/bin/bash
# shop administration (simplified): shop-admin add-product NAME
[ "$1" = add-product ] && [ -n "$2" ] || { echo "usage: shop-admin add-product NAME" >&2; exit 2; }
f=$(echo "$2" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-').txt
echo "image of $2" > /srv/www/shop/images/$f && chown apache:apache /srv/www/shop/images/$f
mysql shop -e "INSERT INTO products (name, image) VALUES ('${2//\'/}', '$f')" && echo "added $2"
SH
chmod 755 /usr/local/bin/shop-admin
chown -R apache:apache $A
cat > /etc/nginx/conf.d/shop.conf <<'CONF'
server {
    listen 80;
    server_name shop.example.test;
    root /srv/www/shop;
    index index.php;
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
CONF
mkdir -p /backup && chmod 700 /backup
systemctl enable --now php-fpm nginx
