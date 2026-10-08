# reference fix (not imported; used by scripts/check_scenarios.py)
tar -xzpf /var/backups/etc-backup-*.tar.gz -C / etc/acme/agent.conf
systemctl restart acme-agent
