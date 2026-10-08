sleep 3
if [ -f /run/media-api/ok ] && [ $(( $(date +%s) - $(stat -c %Y /run/media-api/ok) )) -lt 8 ]; then pass app_writes; else fail app_writes "the media service cannot write"; fi
if runuser -u mediaapp -- touch /srv/media/uploads/.lt-test 2>/dev/null; then pass write_test; rm -f /srv/media/uploads/.lt-test; else fail write_test "mediaapp cannot create files"; fi
m=$(stat -c %a /srv/media/uploads)
[ $(( 0$m & 2 )) -eq 0 ] && [ "$(stat -c %G /srv/media/uploads)" = media ] && pass not_world_writable "mode $m" || fail not_world_writable "mode $m, group $(stat -c %G /srv/media/uploads)"
