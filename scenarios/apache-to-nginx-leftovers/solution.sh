# reference fix (not imported; used by scripts/check_scenarios.py)
systemctl disable --now httpd
python3 - <<'PY'
p = "/etc/nginx/conf.d/shop.conf"
s = open(p).read()
s = s.replace("    index index.php;\n", "    index index.php;\n    location ~ \\.php$ {\n        fastcgi_pass unix:/run/php-fpm/www.sock;\n        include fastcgi_params;\n        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\n    }\n")
open(p, "w").write(s)
PY
chmod 755 /srv/www/shop/catalog
systemctl reload nginx
