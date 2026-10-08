#!/bin/bash
set -e
groupadd -f ops
id ops1 >/dev/null 2>&1 || useradd -m -G ops -s /bin/bash ops1
echo '%ops ALL=(root) NOPASSWD /usr/bin/systemctl' > /etc/sudoers.d/ops
chmod 440 /etc/sudoers.d/ops
