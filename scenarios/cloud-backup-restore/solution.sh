# reference fix (not imported; used by scripts/check_scenarios.py)
L=/var/log/shop-backup.log
cd /srv/www && tar -czf /backup/shop-full-files.tar.gz --listed-incremental=/backup/shop-files.snar shop
mysqldump shop | gzip > /backup/shop-full-db.sql.gz
echo "$(date -Is) full backup done" >> $L
shop-admin add-product "Lemon Cake"
sleep 1
cd /srv/www && tar -czf /backup/shop-incr1-files.tar.gz --listed-incremental=/backup/shop-files.snar shop
mysqldump shop | gzip > /backup/shop-incr1-db.sql.gz
echo "$(date -Is) incremental backup 1 done" >> $L
t=$(mktemp -d)
tar -xzf /backup/shop-full-files.tar.gz --listed-incremental=/dev/null -C $t
tar -xzf /backup/shop-incr1-files.tar.gz --listed-incremental=/dev/null -C $t
rm -rf /srv/www/shop-test && mv $t/shop /srv/www/shop-test && rmdir $t
sed -i "s/\$db_name = 'shop'/\$db_name = 'shop_test'/" /srv/www/shop-test/config.php
mysql -e "CREATE DATABASE shop_test; GRANT ALL ON shop_test.* TO 'shop'@'localhost'"
zcat /backup/shop-incr1-db.sql.gz | mysql shop_test
sed -e 's/server_name shop.example.test/server_name test.shop.example.test/' -e 's#root /srv/www/shop;#root /srv/www/shop-test;#' /etc/nginx/conf.d/shop.conf > /etc/nginx/conf.d/shop-test.conf
systemctl reload nginx
echo "$(date -Is) restore of incremental backup 1 to shop-test done" >> $L
