sleep 3
B=/backup
lst() { tar -tzf "$1" 2>/dev/null; }
dump() { zcat "$1" 2>/dev/null; }
# 1. full: files and database, from before the new product
n=0; d=""
if lst $B/shop-full-files.tar.gz | grep -q 'index\.php$'; then
  lst $B/shop-full-files.tar.gz | grep -q 'lemon-cake' && d="$d full files already contain the change;" || n=$((n+1))
else d="$d no full files backup;"; fi
if dump $B/shop-full-db.sql.gz | grep -q 'Croissant'; then
  dump $B/shop-full-db.sql.gz | grep -q 'Lemon Cake' && d="$d full dump already contains the change;" || n=$((n+1))
else d="$d no full database dump;"; fi
[ $n = 2 ] && pass full_backup || partial full_backup "$(echo "scale=2; $n/2" | bc)" "$d"
# 2. incremental: the change, and not the unchanged files
n=0; d=""
if lst $B/shop-incr1-files.tar.gz | grep -q 'images/lemon-cake\.txt$'; then
  n=$((n+1)); lst $B/shop-incr1-files.tar.gz | grep -q 'catalog-2026\.pdf$' && d="$d the files backup is not incremental (unchanged files in it);" || n=$((n+1))
else d="$d no incremental files backup with the new image;"; fi
dump $B/shop-incr1-db.sql.gz | grep -q 'Lemon Cake' && n=$((n+1)) || d="$d no database dump with the new product;"
[ $n = 3 ] && pass incr_backup || partial incr_backup "$(echo "scale=2; $n/3" | bc)" "$d"
T=/srv/www/shop-test
[ -f $T/index.php ] && [ -f $T/images/lemon-cake.txt ] && [ -f $T/docs/catalog-2026.pdf ] && pass restored_files || fail restored_files "$T is incomplete"
c=$(mysql -N -B shop_test </dev/null -e "SELECT COUNT(*) FROM products WHERE name IN ('Lemon Cake','Croissant')" 2>/dev/null)
[ "$c" = 2 ] && pass restored_db || fail restored_db "shop_test: ${c:-no products table}"
tdb=$(php -r 'include $argv[1]; echo $db_name ?? "";' $T/config.php 2>/dev/null)
body=$(curl -s -m 10 -H 'Host: test.shop.example.test' http://127.0.0.1/)
if [ "$tdb" != shop_test ]; then fail test_site "the test site's config.php uses database '${tdb:-?}'"
elif echo "$body" | grep -q 'Database: shop_test' && echo "$body" | grep -q 'Lemon Cake' && ! echo "$body" | grep -q 'image missing'; then pass test_site
else fail test_site "HTTP $(http_code -H 'Host: test.shop.example.test' http://127.0.0.1/): $(echo "$body" | head -c 120)"; fi
n=0
for w in full incr restor; do grep -qi "$w" /var/log/shop-backup.log 2>/dev/null && n=$((n+1)); done
[ $n = 3 ] && pass backup_log || partial backup_log "$(echo "scale=2; $n/3" | bc)" "$n of 3 steps logged (full, incremental, restore)"
body=$(curl -s -m 10 -H 'Host: shop.example.test' http://127.0.0.1/)
echo "$body" | grep -q 'Database: shop<' && echo "$body" | grep -q 'Lemon Cake' && echo "$body" | grep -q 'Shop OK' || deduct production_broken "$(echo "$body" | head -c 120)"
