sleep 3  # graceful reloads answer with the old config for a moment; opcache re-reads changed files every 2 s
site_ok() {  # site_ok CHECK HOST PATH TEXT
  local code
  code=$(curl -s -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "http://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for http://$2$3"; fi
}
site_ok report_works shop.example.test /report.php 'REPORT OK'
start=$(date +%s.%N)
for i in 1 2 3 4; do curl -s -m 20 -o /tmp/.lt-par-$i -H 'Host: shop.example.test' http://127.0.0.1/page.php & done
wait
took=$(echo "$(date +%s.%N) - $start" | bc 2>/dev/null || python3 -c "print($(date +%s.%N) - $start)")
okn=$(cat /tmp/.lt-par-* 2>/dev/null | grep -c 'PAGE OK')
if [ "$okn" -eq 4 ] && python3 -c "import sys; sys.exit(0 if $took < 2.5 else 1)"; then pass parallel_fast "4 pages in ${took%.*}s"; else fail parallel_fast "$okn/4 pages, ${took}s"; fi
rm -f /tmp/.lt-par-*
check fpm_running systemctl is-active --quiet php-fpm
