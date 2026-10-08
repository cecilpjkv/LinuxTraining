sleep 3  # graceful reloads answer with the old config for a moment; opcache re-reads changed files every 2 s
site_ok() {  # site_ok CHECK HOST PATH TEXT
  local code
  code=$(curl -s -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "http://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for http://$2$3"; fi
}
site_ok shop_works shop.example.test / 'PHP-OK-42'
bad=""; for f in /srv/www/shop/*.php; do php -l "$f" >/dev/null 2>&1 || bad="$bad $f"; done
[ -z "$bad" ] && pass code_valid || fail code_valid "syntax errors in:$bad"
grep -q "'shipping' => 4.95" /srv/www/shop/settings.php && grep -q "'tax_rate' => 0.21" /srv/www/shop/settings.php && pass settings_kept || fail settings_kept "settings values were changed or removed"
if grep -Eqi '^\s*display_errors\s*=\s*(on|1|stdout)' /etc/php.ini /etc/php.d/*.ini 2>/dev/null || grep -Eqi 'display_errors\]\s*=\s*(on|1)' /etc/php-fpm.d/*.conf; then
  fail errors_hidden "display_errors was switched on"
else
  pass errors_hidden
fi
