# reference fix (not imported; used by scripts/check_scenarios.py)
echo '/opt/vendor/lib' > /etc/ld.so.conf.d/vendor-report.conf
ldconfig
sleep 6
