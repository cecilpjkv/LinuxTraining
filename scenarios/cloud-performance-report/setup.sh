#!/bin/bash
set -e
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test' >> /etc/hosts
systemctl enable --now mariadb
for i in $(seq 1 30); do mysqladmin ping >/dev/null 2>&1 </dev/null && break; sleep 1; done
mysql </dev/null -e "CREATE DATABASE IF NOT EXISTS shop; CREATE USER IF NOT EXISTS 'shop'@'localhost' IDENTIFIED BY 'Shop-Db-Pass-7'; GRANT ALL ON shop.* TO 'shop'@'localhost';
  USE shop;
  CREATE TABLE IF NOT EXISTS shop.orders (id INT AUTO_INCREMENT PRIMARY KEY, customer_id INT, total DECIMAL(10,2), created DATETIME);
  INSERT INTO shop.orders (customer_id, total, created) SELECT seq % 300, (seq % 97) + 0.99, NOW() - INTERVAL seq MINUTE FROM seq_1_to_5000;"
# the application directory
A=/srv/www/shop
mkdir -p $A/public $A/var/cache/pages $A/var/log $A/media/products $A/vendor/lib $A/bin
echo '<?php echo "<h1>Example Shop</h1><p>Shop OK</p>";' > $A/public/index.php
for i in $(seq 1 30); do head -c 2M /dev/urandom > $A/var/cache/pages/page-$i.cache; done      # ~60 MB
for i in $(seq 1 12); do head -c 1500K /dev/urandom > $A/media/products/p$i.jpg; done          # ~18 MB
for i in $(seq 1 40); do head -c 200K /dev/urandom > $A/vendor/lib/mod$i.php; done             # ~8 MB
head -c 3M /dev/urandom | base64 > $A/var/log/app.log
cat > /etc/nginx/conf.d/shop.conf <<'CONF'
server {
    listen 80;
    server_name shop.example.test;
    root /srv/www/shop/public;
    index index.php;
    access_log /var/log/nginx/shop.access.log;
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
CONF
# today's traffic, one scraper above the rest
python3 - <<'PY'
import random, time
r = random.Random()
day = time.strftime('%d/%b/%Y')
ips = ["198.51.100.%d" % r.randint(2, 250) for _ in range(30)] + ["192.0.2.%d" % r.randint(2, 250) for _ in range(20)]
heavy = "203.0.113.%d" % r.randint(10, 250)
rows = [(r.choice(ips), r.choice(['/', '/products/', '/cart/', '/search?q=mug'])) for _ in range(r.randint(1500, 1800))]
rows += [(heavy, '/search?q=%d' % r.randint(1, 99999)) for _ in range(r.randint(700, 800))]
rows += [(ips[0], '/') for _ in range(r.randint(300, 400))]   # the runner-up
out = []
for ip, path in rows:
    t = '%s:%02d:%02d:%02d +0000' % (day, r.randint(0, 23), r.randint(0, 59), r.randint(0, 59))
    out.append((t, '%s - - [%s] "GET %s HTTP/1.1" 200 %d "-" "Mozilla/5.0"' % (ip, t, path, r.randint(800, 9000))))
out.sort()
open('/var/log/nginx/shop.access.log', 'w').write('\n'.join(o[1] for o in out) + '\n')
PY
# a product feed export that never sleeps long enough, and a thumbnail cache that holds a lot of memory
cat > $A/bin/feed-export.php <<'PHP'
<?php
// exports the product feed for price comparison sites (runs continuously)
while (true) { $t = microtime(true); while (microtime(true) - $t < 0.06) { hash('sha256', random_bytes(64)); } usleep(40000); }
PHP
mkdir -p /opt/thumbs
cat > /opt/thumbs/thumbnail-cache.py <<'PY'
#!/usr/bin/python3
# keeps generated product thumbnails in memory for the shop
import time
cache = [bytearray(1024 * 1024) for _ in range(140)]
for b in cache:
    b[::4096] = b'\x01' * len(b[::4096])
while True:
    time.sleep(60)
PY
cat > /etc/systemd/system/feed-export.service <<'UNIT'
[Unit]
Description=Shop product feed export
[Service]
User=apache
ExecStart=/usr/bin/php /srv/www/shop/bin/feed-export.php
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
cat > /etc/systemd/system/thumbnail-cache.service <<'UNIT'
[Unit]
Description=Shop thumbnail cache
[Service]
User=apache
ExecStart=/usr/bin/python3 /opt/thumbs/thumbnail-cache.py
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
# the shop's reports: three queries, one of them slower than 2 seconds
cat > /usr/local/bin/shop-reports <<'SH'
#!/bin/bash
# runs the dashboard queries for the shop's back office
while true; do
  mysql --comments -ushop -pShop-Db-Pass-7 shop -e "SELECT /* sales-dashboard */ COUNT(*), SUM(total), SLEEP(0.4) FROM orders WHERE created > NOW() - INTERVAL 1 DAY" >/dev/null 2>&1
  mysql --comments -ushop -pShop-Db-Pass-7 shop -e "SELECT /* stock-sync */ customer_id, SLEEP(1.3) FROM orders WHERE id = 1" >/dev/null 2>&1
  mysql --comments -ushop -pShop-Db-Pass-7 shop -e "SELECT /* customer-lifetime-value */ customer_id, SUM(total), SLEEP(2.6) FROM orders WHERE id = 2 GROUP BY customer_id" >/dev/null 2>&1
  sleep 10
done
SH
chmod 755 /usr/local/bin/shop-reports
cat > /etc/systemd/system/shop-reports.service <<'UNIT'
[Unit]
Description=Shop back-office reports
After=mariadb.service
[Service]
ExecStart=/usr/local/bin/shop-reports
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
chown -R apache:apache $A
systemctl daemon-reload
systemctl enable --now php-fpm nginx feed-export thumbnail-cache shop-reports
cat > /root/answers.txt <<'TXT'
# Performance check for shop.example.test. Fill in each value after the "=".
high_cpu_process=
high_memory_process=
largest_app_dir=
top_ip=
slow_query=
TXT
