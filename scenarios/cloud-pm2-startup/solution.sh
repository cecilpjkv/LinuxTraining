# reference fix: install the PM2 boot service for appops and save the running process list
pm2 startup systemd -u appops --hp /home/appops </dev/null
systemctl enable pm2-appops </dev/null 2>/dev/null || true
runuser -u appops -- bash -lc 'pm2 save' </dev/null
sleep 1
