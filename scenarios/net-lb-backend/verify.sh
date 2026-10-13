if [ "$LT_NODE" = lb ]; then
  sleep 1
  check config_valid nginx -t
  code=$(curl -s -o /tmp/.lt-body -m 10 -w '%{http_code}' -H 'Host: shop.example.test' http://127.0.0.1/)
  if [ "$code" = 200 ] && grep -q 'Shop backend app1 OK' /tmp/.lt-body; then pass shop_works "HTTP $code"; else fail shop_works "HTTP $code through lb"; fi
else
  ss -ltnH | awk '{print $4}' | grep -Eq '^(0\.0\.0\.0|\*|\[::\]|[0-9.]+):8080$' && ! ss -ltnH | awk '{print $4}' | grep -qx '127.0.0.1:8080' \
    && pass backend_listening || fail backend_listening "nginx on app1 does not listen on the network on 8080"
  if nft list chain inet filter input 2>/dev/null | grep -q 'policy drop'; then pass firewall_kept; else fail firewall_kept "app1's firewall (policy drop) is gone"; fi
  if nft list chain inet filter input 2>/dev/null | grep -E 'tcp dport (8080|\{[^}]*8080[^}]*\}) accept' | grep -vq 'saddr'; then deduct port_open_to_all "8080 is open to every address, not just lb"; fi
fi
