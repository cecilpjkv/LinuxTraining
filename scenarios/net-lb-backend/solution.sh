# reference fix (not imported; used by scripts/check_scenarios.py): runs on every server, app1 first
if [ "$LT_NODE" = app1 ]; then
  sed -i 's/listen 127.0.0.1:8080;/listen 8080;/' /etc/nginx/conf.d/shop-backend.conf
  lb=$(getent hosts lb | awk '{print $1; exit}')
  sed -i "s/        tcp dport 22 accept/        tcp dport 22 accept\n        ip saddr $lb tcp dport 8080 accept/" /etc/sysconfig/nftables.conf
  systemctl restart nftables nginx
else
  sed -i 's/server app1:80;/server app1:8080;/' /etc/nginx/conf.d/shop-lb.conf
  systemctl reload nginx
fi
