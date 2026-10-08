sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
served_cert() { echo | openssl s_client -connect 127.0.0.1:443 -servername "$1" 2>/dev/null | openssl x509 -noout "${@:2}" 2>/dev/null; }
chain_ok() { echo | openssl s_client -connect 127.0.0.1:443 -servername "$1" -CAfile "$2" -verify_return_error 2>&1 | grep -q 'Verify return code: 0 (ok)'; }
check config_valid nginx -t
site_ok https_works shop.example.test / 'Shop OK' https
chain_ok shop.example.test /etc/pki/ca-root.crt && pass cert_trusted || fail cert_trusted "the served chain does not verify against the company CA"
loc=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' -H 'Host: shop.example.test' 'http://127.0.0.1/a/b?c=1')
case "$loc" in 30[1278]\ https://shop.example.test/a/b?c=1) pass redirect_correct "$loc";; *) fail redirect_correct "http answered: $loc";; esac
