# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^PORT=.*/PORT=8000/' /etc/shop-api.env
systemctl restart shop-api
sleep 1
