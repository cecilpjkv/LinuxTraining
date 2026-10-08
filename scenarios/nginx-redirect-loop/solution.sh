# reference fix (not imported; used by scripts/check_scenarios.py)
python3 - <<'PY'
p = "/etc/nginx/conf.d/shop.conf"
s = open(p).read()
s = s.replace("""    # make sure everybody uses HTTPS
    if ($host = shop.example.test) {
        return 301 https://$host$request_uri;
    }
""", "")
open(p, "w").write(s)
PY
systemctl reload nginx
