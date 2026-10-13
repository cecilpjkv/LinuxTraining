# reference fix: restore the environment file the service loads (API_TOKEN), then start it
cat > /etc/shop-api.env <<'ENV'
API_TOKEN=prod-7f3c9a21
ENV
chmod 640 /etc/shop-api.env
# the crash loop tripped the start-limit; clear it before starting again
systemctl reset-failed shop-api 2>/dev/null || true
systemctl restart shop-api
sleep 2
