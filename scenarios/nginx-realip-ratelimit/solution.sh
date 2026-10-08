# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|^http {|http {\n    set_real_ip_from 127.0.0.1;\n    real_ip_header X-Forwarded-For;|' /etc/nginx/nginx.conf
systemctl reload nginx
