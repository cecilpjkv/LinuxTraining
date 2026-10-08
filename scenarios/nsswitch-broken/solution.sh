# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's/^passwd:.*/passwd:     files/; s/^group:.*/group:      files/; s/^shadow:.*/shadow:     files/' /etc/nsswitch.conf
systemctl restart ledger-api
