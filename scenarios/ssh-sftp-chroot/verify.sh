o="-i /etc/lt-ssh-test/acme -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR"
name=lt-check-$RANDOM.csv
echo 'order-2002;1;gadget' > /tmp/$name
if sftp $o -b - acme@127.0.0.1 >/tmp/.lt-sftp 2>&1 <<B && [ -f /srv/sftp/acme/upload/$name ]
cd upload
put /tmp/$name
B
then pass upload_works; else fail upload_works "$(tail -2 /tmp/.lt-sftp | tr '\n' ' ')"; fi
rm -f /tmp/$name /srv/sftp/acme/upload/$name
out=$(ssh -n $o acme@127.0.0.1 'id; cat /etc/hostname' 2>&1)
if printf '%s' "$out" | grep -q 'uid='; then fail no_shell "acme can run commands: $out"; else pass no_shell; fi
bad=""
for d in /srv/sftp /srv/sftp/acme; do
  [ "$(stat -c %U "$d")" = root ] || bad="$bad $d(owner $(stat -c %U "$d"))"
  [ $(( 0$(stat -c %a "$d") & 022 )) -eq 0 ] || bad="$bad $d(mode $(stat -c %a "$d"))"
done
sshd -T 2>/dev/null -C user=acme,host=x,addr=127.0.0.1 | grep -qi '^chrootdirectory /srv/sftp/' || bad="$bad (no chroot for acme)"
[ -z "$bad" ] && pass chroot_secure || fail chroot_secure "$bad"
