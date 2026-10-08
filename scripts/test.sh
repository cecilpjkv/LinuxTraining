#!/bin/sh
# Runs the backend test suite on the runtime host in a dev image (pytest included) on the compose network, against
# the linuxtraining_test database only (tests/conftest.py refuses any other).
#   scripts/test.sh [pytest args]       (run on the runtime host, from the checkout: /opt/linuxtraining)
set -eu
cd "$(dirname "$0")/../deploy"
docker build -q --build-arg DEV=1 -t linuxtraining-backend-dev ../backend >/dev/null
docker run --rm --network linuxtraining_app -v /var/run/docker.sock:/var/run/docker.sock \
  -e LT_DATABASE_URL="postgresql+psycopg://linuxtraining:$(sed -n 's/^LT_DB_PASSWORD=//p' .env)@db:5432/linuxtraining" \
  -v "$PWD/../backend:/app" -v "$PWD/../scenarios:/srv/scenarios:ro" linuxtraining-backend-dev pytest -q "$@"
