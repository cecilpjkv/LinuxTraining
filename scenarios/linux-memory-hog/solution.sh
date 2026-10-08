# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^CACHE_MB=.*/CACHE_MB=64/' /etc/sysconfig/cache-warmer
systemctl restart cache-warmer
