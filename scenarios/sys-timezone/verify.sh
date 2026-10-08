l=$(readlink -f /etc/localtime)
case "$l" in */Europe/Amsterdam) pass timezone_set "$l";; *) fail timezone_set "/etc/localtime -> $l";; esac
z=$(date +%Z); case "$z" in CET|CEST) pass clock_shows_zone "$z";; *) fail clock_shows_zone "date shows $z";; esac
