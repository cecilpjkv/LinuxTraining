#!/bin/bash
set -e
mkdir -p /srv/www/shop
echo '<!doctype html><title>Shop</title><h1>Example Shop</h1><p>Shop OK</p>' > /srv/www/shop/index.html
grep -q 'shop.example.test' /etc/hosts || echo '127.0.0.1 shop.example.test' >> /etc/hosts
cat > /etc/httpd/conf.d/shop.conf <<'CONF'
<VirtualHost *:80>
    ServerName shop.example.test
    DocumentRoot /srv/www/shop
    ErrorLog logs/shop.example.test-error_log
    CustomLog /var/log/httpd/vhosts/shop.example.test-access_log combined
</VirtualHost>
<Directory /srv/www/shop>
    Require all granted
</Directory>
CONF
mkdir -p /var/log/httpd/vhosts
systemctl enable --now httpd
# today's traffic: normal visitors, a crawler, a bot hammering the login, broken links and a failing endpoint.
# Some 200 lines carry "404", "500" or "301" in the URL or the size, so counting with plain grep gives wrong numbers.
python3 - <<'PY'
import random, time
r = random.Random()
day = time.strftime('%d/%b/%Y')
bot = "203.0.113.%d" % r.randint(20, 220)
ips = ["198.51.100.%d" % r.randint(2, 250) for _ in range(40)] + ["192.0.2.%d" % r.randint(2, 250) for _ in range(25)]
crawler = "66.249.66.%d" % r.randint(1, 200)
uas = ['Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36',
       'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
       'Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0']
ok = ['/', '/products/', '/products/blue-mug', '/products/red-mug', '/cart/', '/css/site.css', '/js/app.js',
      '/img/logo.png', '/blog/how-we-fixed-404-errors', '/blog/500-orders-milestone', '/promo/301-sale', '/about/']
lines = []
def add(ip, path, status, ua=None, method='GET'):
    size = {301: 235, 403: 199, 404: 196, 500: 531}.get(status) or r.choice([404, 500, 301, 1830, 5120, 2210, 14562, 813])
    h, m, s = r.randint(0, 23), r.randint(0, 59), r.randint(0, 59)
    lines.append((h, m, s, '%s - - [%s:%02d:%02d:%02d +0000] "%s %s HTTP/1.1" %d %d "-" "%s"' %
                  (ip, day, h, m, s, method, path, status, size, ua or r.choice(uas))))
for _ in range(r.randint(1400, 1700)):
    add(r.choice(ips), r.choice(ok), 200)
for _ in range(r.randint(600, 700)):
    add(crawler, r.choice(ok), 200, 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)')
for _ in range(r.randint(120, 180)):
    add(r.choice(ips), r.choice(['/shop', '/old-catalog/', '/index.php?page=home']), 301)
for _ in range(r.randint(60, 90)):
    add(r.choice(ips), r.choice(['/.env', '/.git/config', '/admin/backup.zip']), 403)
for _ in range(r.randint(200, 260)):
    add(r.choice(ips), r.choice(['/products/green-mug', '/wp-login.php', '/favicon.ico', '/img/banner-2023.jpg']), 404)
for _ in range(r.randint(30, 60)):
    add(r.choice(ips), '/api/checkout', 500, method='POST')
for _ in range(r.randint(900, 1100)):  # the bot: more than the crawler
    add(bot, r.choice(['/login', '/login', '/cart/', '/xmlrpc.php']), r.choice([200, 200, 403, 404]), 'python-requests/2.31.0', 'POST')
lines.sort()
with open('/var/log/httpd/vhosts/shop.example.test-access_log', 'w') as f:
    f.write('\n'.join(l[3] for l in lines) + '\n')
PY
# the default log only has the health checks of the old monitoring
for i in $(seq 1 40); do echo "127.0.0.1 - - [$(date '+%d/%b/%Y:%H:%M:%S %z')] \"GET / HTTP/1.1\" 200 45 \"-\" \"check_http/v2.4\"" ; done > /var/log/httpd/access_log
cat > /root/answers.txt <<'TXT'
# Traffic report for shop.example.test (today). Fill in each value after the "=".
access_log=
count_200=
count_301=
count_403=
count_404=
count_500=
top_ip=
TXT
