sleep 2
if [ -d /etc/booking ] && diff -q <(cd /etc/booking && find . -type f -exec sha256sum {} + | sort -k2) /var/lib/lt-booking/sums >/dev/null; then
  pass files_restored
else
  fail files_restored "/etc/booking does not hold the original files"
fi
if [ -d /etc/booking ] && diff <(cd /etc/booking && find . -printf '%p %u %g %m\n' | sort) /var/lib/lt-booking/modes >/tmp/.lt-modes 2>&1; then
  pass owners_modes
else
  fail owners_modes "$(grep '^<' /tmp/.lt-modes | head -3 | tr '\n' ' ')"
fi
if systemctl is-active --quiet booking && curl -s -m 5 http://127.0.0.1:8085/ | grep -q 'booking ok'; then pass service_running; else fail service_running "the booking service does not answer on 127.0.0.1:8085"; fi
