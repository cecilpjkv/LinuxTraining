# reference fix (not imported; used by scripts/check_scenarios.py)
grep -v '^10.9.9.9' /etc/hosts > /tmp/hosts.new && echo '127.0.0.1   db.internal' >> /tmp/hosts.new && cat /tmp/hosts.new > /etc/hosts
