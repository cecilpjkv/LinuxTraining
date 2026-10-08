#!/bin/sh
# Copies the working tree (tracked and new, not ignored files) to the runtime host, where Docker builds and runs it.
#   scripts/sync.sh            uses LT_SSH (default: /home/csfnew/.testhost/ssh.sh) and LT_DIR (default /opt/linuxtraining)
set -eu
cd "$(dirname "$0")/.."
SSH=${LT_SSH:-/home/csfnew/.testhost/ssh.sh}
DIR=${LT_DIR:-/opt/linuxtraining}
# files that exist (a deleted but not yet committed file is still listed by git)
git ls-files -co --exclude-standard -z | xargs -0 -I{} sh -c '[ -e "{}" ] && printf "%s\0" "{}"' | tar --null -T - -czf - | "$SSH" "mkdir -p $DIR && tar -xzf - -C $DIR"
echo "synced to $DIR"
