avail=$(df -Pk /srv/data | awk 'NR==2{print $4}')
[ "$avail" -ge 16384 ] && pass space_freed "$((avail/1024)) MB free" || fail space_freed "only $((avail/1024)) MB free"
if head -c 5M /dev/zero > /srv/data/uploads/.lt-write-test 2>/dev/null; then pass can_write; else fail can_write "a 5 MB write fails"; fi
rm -f /srv/data/uploads/.lt-write-test
n=$(ls /srv/data/uploads/customer-*.jpg 2>/dev/null | wc -l)
[ "$n" -eq 30 ] && pass uploads_intact || fail uploads_intact "$n of 30 customer files left"
