# reference answers (not imported; used by scripts/check_scenarios.py)
LOG=$(awk '/CustomLog/{print $2}' /etc/httpd/conf.d/shop.conf)
{ echo "access_log=$LOG"
  for c in 200 301 403 404 500; do echo "count_$c=$(awk -v c=$c '$9 == c' "$LOG" | wc -l)"; done
  echo "top_ip=$(awk '{print $1}' "$LOG" | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')"; } > /root/answers.txt
