#!/bin/bash
set -e
for i in nginx php-8.1-fpm-alpine php-8.3-fpm-alpine mariadb-10.11.14 mariadb-10.11.18; do
  podman load -q -i /opt/lt-images/$i.tar >/dev/null
done
mkdir -p /srv/shop/src
cat > /srv/shop/compose.yaml <<'YAML'
name: shop
services:
  web:
    image: docker.io/library/nginx:1.27-alpine
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./src:/var/www/html:ro
    depends_on:
      - php
  php:
    image: docker.io/library/php:8.1-fpm-alpine
    restart: unless-stopped
    env_file: shop.env
    volumes:
      - ./src:/var/www/html:ro
  db:
    image: docker.io/library/mariadb:10.11.18
    restart: unless-stopped
    env_file: shop.env
    volumes:
      - dbdata:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mariadb-admin", "ping", "-h", "127.0.0.1"]
      interval: 10s
      retries: 5
volumes:
  dbdata:
YAML
cat > /srv/shop/shop.env <<'ENV'
MARIADB_ROOT_PASSWORD=Root-Db-Pass-62
MARIADB_DATABASE=shop
MARIADB_USER=shop
MARIADB_PASSWORD=Shop-Db-Pass-62
DB_HOST=db
ENV
cat > /srv/shop/nginx.conf <<'CONF'
server {
    listen 80;
    root /var/www/html;
    index index.php;
    location ~ \.php$ {
        fastcgi_pass php:9000;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
CONF
cat > /srv/shop/src/index.php <<'PHP'
<?php
// Example Shop 3.0
if (version_compare(PHP_VERSION, '8.3.0', '<')) {
    http_response_code(500);
    exit("Example Shop 3.0 requires PHP 8.3 or newer (this is PHP " . PHP_VERSION . ")\n");
}
$db = @new mysqli(getenv('DB_HOST'), getenv('MARIADB_USER'), getenv('MARIADB_PASSWORD'), getenv('MARIADB_DATABASE'));
if ($db->connect_errno) { http_response_code(500); exit("Database error: " . $db->connect_error . "\n"); }
$n = $db->query("SELECT COUNT(*) FROM orders")->fetch_row()[0];
echo "<h1>Example Shop 3.0</h1><p>PHP " . PHP_VERSION . " | MariaDB " . $db->server_info . " | orders: $n</p>\n";
PHP
cd /srv/shop
docker compose up -d --quiet-pull >/dev/null 2>&1 </dev/null
for i in $(seq 1 60); do docker compose exec -T db mariadb-admin ping -h 127.0.0.1 >/dev/null 2>&1 </dev/null && break; sleep 1; done
docker compose exec -T db mariadb -uroot -pRoot-Db-Pass-62 shop </dev/null -e "
  CREATE TABLE IF NOT EXISTS orders (id INT AUTO_INCREMENT PRIMARY KEY, customer VARCHAR(60), total DECIMAL(10,2), created DATETIME);
  INSERT INTO orders (customer, total, created) VALUES
    ('Alice Martin', 42.50, NOW() - INTERVAL 9 DAY), ('Bob Chen', 18.00, NOW() - INTERVAL 8 DAY),
    ('Carla Diaz', 77.25, NOW() - INTERVAL 6 DAY), ('Dev Patel', 12.99, NOW() - INTERVAL 4 DAY),
    ('Emma Rossi', 230.00, NOW() - INTERVAL 2 DAY), ('Farid Haddad', 64.10, NOW() - INTERVAL 1 DAY);"
docker compose exec -T db mariadb -uroot -pRoot-Db-Pass-62 -N -B shop </dev/null -e "SELECT COUNT(*), SUM(total), GROUP_CONCAT(customer ORDER BY id) FROM orders" > /var/lib/.lt-orders
docker volume inspect shop_dbdata --format '{{.CreatedAt}}' > /var/lib/.lt-volume
