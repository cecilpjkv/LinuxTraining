# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|        proxy_set_header Host $host;|        proxy_set_header Host $host;\n        proxy_set_header X-Forwarded-Proto https;|' /etc/nginx/conf.d/wp-tls.conf
sed -i "s|^<?php|<?php\nif ( isset( \$_SERVER['HTTP_X_FORWARDED_PROTO'] ) \&\& \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https' ) { \$_SERVER['HTTPS'] = 'on'; }|" /srv/www/wp/wp-config.php
systemctl reload nginx
