#!/bin/sh
# Proves the scenario packages in real labs (see scripts/check_scenarios.py). Run on the Docker host:
#   scripts/check-scenarios.sh [name-or-prefix ...]
set -eu
cd "$(dirname "$0")/.."
docker build -q --build-arg DEV=1 -t linuxtraining-backend-dev backend >/dev/null
docker run --rm -v /run/lt-labs:/run/lt-labs -e DOCKER_HOST=unix:///run/lt-labs/docker.sock -v "$PWD/backend:/app" -v "$PWD/scenarios:/srv/scenarios:ro" \
  -v "$PWD/scripts:/scripts:ro" -e LT_DATABASE_URL=postgresql+psycopg://x:x@localhost/x linuxtraining-backend-dev \
  python /scripts/check_scenarios.py "$@"
