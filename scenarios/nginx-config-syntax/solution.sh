# reference fix (not imported): restore the missing semicolon, test, restart
sed -i 's|add_header X-Shop-Version "2.4"$|add_header X-Shop-Version "2.4";|' /etc/nginx/conf.d/shop.conf
nginx -t && systemctl restart nginx
