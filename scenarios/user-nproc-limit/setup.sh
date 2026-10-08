#!/bin/bash
set -e
id builder >/dev/null 2>&1 || useradd -m -s /bin/bash builder
printf '# limit runaway builds (INC-2210)\nbuilder  soft  nproc  8\nbuilder  hard  nproc  8\n' > /etc/security/limits.d/90-builder.conf
