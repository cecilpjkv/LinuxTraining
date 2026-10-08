# reference fix (not imported; used by scripts/check_scenarios.py)
dnf -y -q install php-mbstring
systemctl restart php-fpm
sleep 1
