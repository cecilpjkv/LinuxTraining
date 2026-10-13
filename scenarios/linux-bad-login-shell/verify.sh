sh=$(getent passwd deploy | cut -d: -f7)
if [ -x "$sh" ] && [ "$sh" != /usr/sbin/nologin ] && [ "$sh" != /sbin/nologin ] && [ "$sh" != /bin/false ]; then pass shell_valid "$sh"; else fail shell_valid "shell is '${sh:-none}'"; fi
out=$(runuser -l deploy -c 'echo LOGIN-OK' 2>/tmp/.lt-lerr)
[ "$out" = LOGIN-OK ] && pass login_works || fail login_works "$(tr -d '\n' </tmp/.lt-lerr)"
if [ -d /home/deploy ] && [ "$(stat -c %U /home/deploy)" = deploy ]; then pass home_intact; else fail home_intact "home missing or not owned by deploy"; fi
