sleep 1  # a graceful reload lets old workers answer for a moment
site_ok() {  # site_ok CHECK HOST PATH TEXT [scheme]
  local code
  code=$(curl -sk -o /tmp/.lt-body -m 15 -w '%{http_code}' -H "Host: $2" "${5:-http}://127.0.0.1$3")
  if [ "$code" = 200 ] && grep -q "$4" /tmp/.lt-body; then pass "$1" "HTTP $code"; else fail "$1" "HTTP $code for ${5:-http}://$2$3"; fi
}
served_cert() { echo | openssl s_client -connect 127.0.0.1:443 -servername "$1" 2>/dev/null | openssl x509 -noout "${@:2}" 2>/dev/null; }
chain_ok() { echo | openssl s_client -connect 127.0.0.1:443 -servername "$1" -CAfile "$2" -verify_return_error 2>&1 | grep -q 'Verify return code: 0 (ok)'; }
chain_ok shop.example.test /etc/pki/ca-root.crt && pass chain_complete || fail chain_complete "the chain does not verify with only the root CA"
site_ok https_works shop.example.test / 'Shop OK' https
n=$(echo | openssl s_client -connect 127.0.0.1:443 -servername shop.example.test -showcerts 2>/dev/null | grep -c 'BEGIN CERTIFICATE')
[ "$n" -ge 2 ] && pass sends_intermediate "$n certificates" || fail sends_intermediate "the server sends $n certificate(s)"
