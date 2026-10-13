# reference fix: make the PHP session directory writable by the php-fpm user (apache) again
S=/var/lib/php/session
chown root:apache "$S"
chmod 0770 "$S"
