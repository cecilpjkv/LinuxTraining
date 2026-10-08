sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
curl -s -m 10 -H 'Host: portal.example.test' http://127.0.0.1/files/ | grep -q 'Index of' && fail no_listing "/files/ still lists its contents" || pass no_listing
c=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: portal.example.test' http://127.0.0.1/files/portal-backup-2024.sql)
[ "$c" = 403 ] || [ "$c" = 404 ] && pass dump_not_downloadable "HTTP $c" || fail dump_not_downloadable "the dump answers HTTP $c"
site_ok files_work portal.example.test /files/brochure.txt 'BROCHURE'
site_ok portal_works portal.example.test / 'Portal OK'
