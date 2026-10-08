# reference fix (not imported; used by scripts/check_scenarios.py)
usermod -aG certs webproxy
systemctl restart tls-proxy
