m() { stat -c %a "$1"; }
[ "$(m /etc/passwd)" = 644 ] && [ "$(m /etc/group)" = 644 ] && pass account_files_readable || fail account_files_readable "passwd $(m /etc/passwd), group $(m /etc/group)"
[ $(( 0$(m /etc/shadow) & 077 )) -eq 0 ] && [ $(( 0$(m /etc/gshadow) & 077 )) -eq 0 ] && pass hashes_private || fail hashes_private "shadow $(m /etc/shadow), gshadow $(m /etc/gshadow)"
sleep 1
curl -s -m 5 http://127.0.0.1:8096/ | grep -q 'status ok' && pass services_work || fail services_work "status-api is not answering"
