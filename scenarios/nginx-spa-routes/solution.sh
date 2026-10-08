# reference fix (not imported; used by scripts/check_scenarios.py)
python3 - <<'PY'
p = "/etc/nginx/conf.d/shop.conf"
s = open(p).read()
s = s.replace("    index index.html;\n", "    index index.html;\n    location /assets/ { try_files $uri =404; }\n    location / { try_files $uri $uri/ /index.html; }\n", 1)
open(p, "w").write(s)
PY
systemctl reload nginx
