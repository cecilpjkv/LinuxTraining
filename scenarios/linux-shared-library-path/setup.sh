#!/bin/bash
set -e
mkdir -p /opt/vendor/bin /opt/vendor/lib /var/lib/report
cp /usr/bin/jq /opt/vendor/bin/report-tool
# the vendor package ships its own copy of the library; its installer removed the distribution's copy
cp -a /usr/lib64/libjq.so.1* /opt/vendor/lib/
rm -f /usr/lib64/libjq.so.1*
echo '/opt/vendor/lib64' > /etc/ld.so.conf.d/vendor-report.conf
ldconfig
cat > /opt/vendor/bin/report-export <<'SH'
#!/bin/bash
# writes the current order report every 5 seconds
while true; do
  if printf '{"orders": %d, "generated": %d}' $((RANDOM % 100)) "$(date +%s)" | /opt/vendor/bin/report-tool -c '. + {status: "ok"}' > /var/lib/report/latest.json.tmp 2>>/var/lib/report/errors.log; then
    mv /var/lib/report/latest.json.tmp /var/lib/report/latest.json
  fi
  sleep 5
done
SH
chmod 755 /opt/vendor/bin/report-export
cat > /etc/systemd/system/report-export.service <<'UNIT'
[Unit]
Description=Vendor report export

[Service]
ExecStart=/opt/vendor/bin/report-export
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now report-export
