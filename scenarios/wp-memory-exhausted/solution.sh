# reference fix (not imported; used by scripts/check_scenarios.py)
cat > /etc/php-fpm.d/wp.conf <<'X'
[wp]
user = apache
group = apache
listen = /run/php-fpm/wp.sock
listen.acl_users = apache,nginx
pm = ondemand
pm.max_children = 5
php_admin_value[memory_limit] = 256M
X
sed -i 's|fastcgi_pass unix:/run/php-fpm/www.sock;|fastcgi_pass unix:/run/php-fpm/wp.sock;|' /etc/nginx/conf.d/wp.conf
systemctl restart php-fpm && systemctl reload nginx
