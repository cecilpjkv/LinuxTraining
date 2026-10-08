sleep 3  # graceful reloads answer with the old config for a moment; opcache re-reads changed files every 2 s
site_ok() {  # site_ok CHECK HOST PATH TEXT
  local code
  code=$(curl -s -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "http://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for http://$2$3"; fi
}
sql() { mysql -N -B "$@" </dev/null 2>&1; }
rows_ok() { [ "$(sql -uroot -e 'SELECT COUNT(*) FROM shopdb.products' "$@")" = 3 ]; }
site_ok shop_works shop.example.test / 'Product C'
grep -Eq "^\\\$DB_USER *= *'shopapp'" /srv/www/shop/config.php && pass own_account || fail own_account "the shop does not use the shopapp account"
[ "$(sql -h127.0.0.1 -ushopapp -p'Rotated-Shop-9f2e!' -e 'SELECT 1')" = 1 ] && pass rotation_kept || fail rotation_kept "the rotated password no longer works (rotation undone)"
