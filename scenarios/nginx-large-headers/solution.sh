# reference fix (not imported; used by scripts/check_scenarios.py)
sed -i 's|    server_name api.example.test;|    server_name api.example.test;\n    large_client_header_buffers 4 16k;\n    proxy_buffer_size 32k;\n    proxy_buffers 8 32k;|' /etc/nginx/conf.d/api.conf
systemctl reload nginx
