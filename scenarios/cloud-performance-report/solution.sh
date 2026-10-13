# reference fix (not imported; used by scripts/check_scenarios.py)
printf '[mysqld]\nslow_query_log = 1\nslow_query_log_file = /var/log/mariadb/slow.log\nlong_query_time = 2\n' > /etc/my.cnf.d/slow-log.cnf
mysql -e "SET GLOBAL slow_query_log_file='/var/log/mariadb/slow.log'; SET GLOBAL long_query_time=2; SET GLOBAL slow_query_log=1"
cpu=$(ps -eo comm,args --sort=-%cpu --no-headers | awk 'NR==1{print $2, $3}')
mem=$(ps -eo args --sort=-rss --no-headers | head -1)
dir=$(du -s /srv/www/shop/*/* | sort -rn | awk 'NR==1{print $2}')
ip=$(awk '{print $1}' /var/log/nginx/shop.access.log | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')
for i in $(seq 1 40); do grep -q 'customer-lifetime-value' /var/log/mariadb/slow.log 2>/dev/null && break; sleep 1; done
slow=$(grep -o '/\* [a-z-]* \*/' /var/log/mariadb/slow.log | sort -u | tr -d '/* ')
printf 'high_cpu_process=%s\nhigh_memory_process=%s\nlargest_app_dir=%s\ntop_ip=%s\nslow_query=%s\n' "$cpu" "$mem" "$dir" "$ip" "$slow" > /root/answers.txt
cat /root/answers.txt
