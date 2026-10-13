#!/bin/bash
set -e
podman load -q -i /opt/lt-images/busybox.tar >/dev/null
mkdir -p /srv/worker/state
cat > /srv/worker/worker.sh <<'SH'
#!/bin/sh
# queue worker: needs QUEUE_URL (redis://HOST:PORT/DB) and WORKER_CONCURRENCY
if [ -z "$QUEUE_URL" ]; then echo "FATAL: QUEUE_URL is not set" >&2; exit 1; fi
case "$QUEUE_URL" in redis://*) ;; *) echo "FATAL: QUEUE_URL must start with redis:// (got $QUEUE_URL)" >&2; exit 1;; esac
echo "worker started: queue $QUEUE_URL, concurrency ${WORKER_CONCURRENCY:-1}"
while true; do date +%s > /state/heartbeat; sleep 2; done
SH
chmod 755 /srv/worker/worker.sh
cat > /srv/worker/README <<'TXT'
Queue worker
  QUEUE_URL           redis://queue.internal:6379/2   (production queue)
  WORKER_CONCURRENCY  4
Deploy: docker compose up -d   (settings in worker.env)
TXT
cat > /srv/worker/worker.env <<'ENV'
# queue worker settings
#QUEUE_URL=redis://queue.internal:6379/2
QUEUE_ULR=redis://queue.internal:6379/2
WORKER_CONCURRENCY=4
ENV
cat > /srv/worker/compose.yaml <<'YAML'
name: worker
services:
  worker:
    image: docker.io/library/busybox:1.36
    restart: always
    command: ["/app/worker.sh"]
    env_file: worker.env
    volumes:
      - ./worker.sh:/app/worker.sh:ro
      - ./state:/state
YAML
cd /srv/worker && docker compose up -d >/dev/null 2>&1
