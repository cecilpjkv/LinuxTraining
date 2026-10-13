# reference fix (not imported; used by scripts/check_scenarios.py)
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q --only-upgrade nginx nginx-common
systemctl restart nginx
