#!/bin/sh
# Builds the training lab images (run on the Docker host): base -> web -> lamp.
set -eu
cd "$(dirname "$0")"
for i in base web lamp; do
  docker build -t "linux-training-$i:latest" "$i"
done
docker images 'linux-training-*' --format '{{.Repository}}:{{.Tag}} {{.Size}}'
