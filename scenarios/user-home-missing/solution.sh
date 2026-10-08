# reference fix (not imported; used by scripts/check_scenarios.py)
cp -a /etc/skel /home/analyst
install -d -m 700 /home/analyst/.ssh
install -m 600 /root/keys/analyst.pub /home/analyst/.ssh/authorized_keys
chown -R analyst: /home/analyst
chmod 700 /home/analyst
