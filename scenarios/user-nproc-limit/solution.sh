# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/nproc  8$/nproc  4096/' /etc/security/limits.d/90-builder.conf
