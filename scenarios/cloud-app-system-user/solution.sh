# reference fix (not imported; used by scripts/check_scenarios.py)
useradd -m -s /bin/bash shopdev
install -d -m 700 -o shopdev -g shopdev /home/shopdev/.ssh
install -m 600 -o shopdev -g shopdev /root/shopdev.pub /home/shopdev/.ssh/authorized_keys
chown -R shopdev:apache /srv/www/shop
find /srv/www/shop -type d -exec chmod 2751 {} +
find /srv/www/shop -type f -exec chmod 640 {} +
chmod 2770 /srv/www/shop/uploads
chown root:apache /srv/www/blog/config.php
chmod 640 /srv/www/blog/config.php
