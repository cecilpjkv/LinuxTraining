out=$(su - builder -c 'for i in $(seq 1 30); do sleep 2 & done; wait && echo ALL-STARTED' 2>&1 </dev/null)
case "$out" in *ALL-STARTED*) pass parallel_build;; *) fail parallel_build "$(printf '%s' "$out" | head -c 120)";; esac
n=$(su - builder -c 'ulimit -u' 2>/dev/null </dev/null)
[ "$n" = unlimited ] || [ "${n:-0}" -ge 100 ] 2>/dev/null && pass limit_raised "nproc $n" || fail limit_raised "nproc ${n:-?}"
