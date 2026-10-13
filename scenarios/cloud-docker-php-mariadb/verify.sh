sleep 2
cd /srv/shop 2>/dev/null || cd /
body=$(curl -s -m 10 http://127.0.0.1:8080/)
if echo "$body" | grep -q 'PHP 8\.3\.'; then
  c=$(docker ps --filter ancestor=docker.io/library/php:8.3-fpm-alpine --filter status=running -q | head -1)
  [ -n "$c" ] && docker exec "$c" php -v 2>/dev/null | grep -q '^PHP 8\.3' && pass php83_serves || fail php83_serves "no running php:8.3-fpm-alpine container"
else fail php83_serves "$(echo "$body" | head -c 150)"; fi
db=$(docker ps --filter label=com.docker.compose.service=db --filter status=running -q | head -1)
if [ -z "$db" ]; then
  fail db_version "the db service is not running"; fail db_healthy "the db service is not running"; fail data_intact "no database"
else
  img=$(docker inspect "$db" --format '{{.Config.Image}}')
  v=$(docker exec "$db" mariadb -uroot -pRoot-Db-Pass-62 -N -B </dev/null -e 'SELECT VERSION()' 2>/dev/null)
  case "$img $v" in *mariadb:10.11.14\ 10.11.14*) pass db_version "$v";; *) fail db_version "image $img, server ${v:-?}";; esac
  docker exec "$db" mariadb-admin ping -h 127.0.0.1 >/dev/null 2>&1 </dev/null && echo "$body" | grep -q 'orders:' && pass db_healthy || fail db_healthy "the database does not answer the shop"
  got=$(docker exec "$db" mariadb -uroot -pRoot-Db-Pass-62 -N -B shop </dev/null -e "SELECT COUNT(*), SUM(total), GROUP_CONCAT(customer ORDER BY id) FROM orders" 2>/dev/null)
  [ -n "$got" ] && [ "$got" = "$(cat /var/lib/.lt-orders)" ] && pass data_intact || fail data_intact "orders: ${got:-none}"
fi
run=$(docker ps --filter status=running --format '{{.Label "com.docker.compose.project"}} {{.Label "com.docker.compose.service"}}' | sort -u)
n=$(echo "$run" | grep -c '^shop ')
[ "$n" -ge 3 ] && ! echo "$run" | grep -qv '^shop ' && pass compose_managed "$(echo $run)" || fail compose_managed "running: $(echo $run)"
created=$(docker volume inspect shop_dbdata --format '{{.CreatedAt}}' 2>/dev/null)
[ "$created" = "$(cat /var/lib/.lt-volume)" ] || deduct data_lost "the volume shop_dbdata is ${created:+new}${created:-gone}"
