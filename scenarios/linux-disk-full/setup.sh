#!/bin/bash
set -e
mkdir -p /srv/data/uploads /srv/data/exports /var/log/upload-api
for i in $(seq -w 1 30); do head -c 20000 /dev/urandom > /srv/data/uploads/customer-$i.jpg; done
# a full export someone made and forgot about
head -c 40M /dev/zero > /srv/data/exports/full-export-2024-03.tar
head -c 22M /dev/zero > /srv/data/exports/full-export-2024-02.tar 2>/dev/null || true
for i in 1 2 3; do echo "$(date '+%F %T') ERROR upload failed: [Errno 28] No space left on device: '/srv/data/uploads/tmp-$RANDOM'" >> /var/log/upload-api/error.log; done
