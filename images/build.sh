#!/bin/sh
# Builds the training lab images base -> web -> lab on the main Docker daemon (it has network access for dnf), then
# loads them into the lab daemon (LAB_DOCKER_HOST, default unix:///run/docker-labs.sock; see deploy/docker-labs),
# which has no default network and runs the labs user-namespace remapped.
set -eu
cd "$(dirname "$0")"
LAB=${LAB_DOCKER_HOST:-unix:///run/docker-labs.sock}
for i in base web lamp; do
  docker build -t "linux-training-$i:latest" "$i"
done
docker save linux-training-base:latest linux-training-web:latest linux-training-lamp:latest | docker -H "$LAB" load
docker -H "$LAB" image prune -f >/dev/null
docker -H "$LAB" images 'linux-training-*' --format '{{.Repository}}:{{.Tag}} {{.Size}}'
