#!/bin/sh
# Builds the training lab images base -> web -> lamp -> cloud, devops (on base) and debian (Debian 12) on the main Docker daemon (it has network access for dnf), then
# loads them into the lab daemon (LAB_DOCKER_HOST, default unix:///run/lt-labs/docker.sock; see deploy/docker-labs),
# which has no default network and runs the labs user-namespace remapped.
set -eu
cd "$(dirname "$0")"
LAB=${LAB_DOCKER_HOST:-unix:///run/lt-labs/docker.sock}
# container images the devops labs run inside themselves (no registry in a lab): one flattened layer each, since the
# lab's container storage (vfs) copies every layer
ctr() {  # ctr TAG CONTEXT WORKDIR CMD [build args...]
  tag=$1 ctx=$2 wd=$3 cmd=$4; shift 4
  docker build -q -t lt-ctr-build "$@" "$ctx" >/dev/null
  id=$(docker create lt-ctr-build)
  docker export "$id" | docker import --change "CMD $cmd" --change "WORKDIR $wd" \
    --change 'ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' - "$tag" >/dev/null
  docker rm "$id" >/dev/null
}
mkdir -p devops/lt-images
ctr docker.io/library/php:8.1-fpm-alpine containers/php /var/www/html '["php-fpm","-F"]' --build-arg ALPINE=3.19 --build-arg PHP=81
ctr docker.io/library/php:8.3-fpm-alpine containers/php /var/www/html '["php-fpm","-F"]' --build-arg ALPINE=3.20 --build-arg PHP=83
ctr docker.io/library/mariadb:10.11.14 containers/mariadb / '["/usr/local/bin/docker-entrypoint.sh"]' --build-arg ALPINE=3.19
ctr docker.io/library/mariadb:10.11.18 containers/mariadb / '["/usr/local/bin/docker-entrypoint.sh"]' --build-arg ALPINE=3.20
docker save -o devops/lt-images/php.tar docker.io/library/php:8.1-fpm-alpine docker.io/library/php:8.3-fpm-alpine
docker save -o devops/lt-images/mariadb.tar docker.io/library/mariadb:10.11.14 docker.io/library/mariadb:10.11.18
docker rmi lt-ctr-build >/dev/null
for i in base web lamp cloud devops; do
  docker build -t "linux-training-$i:latest" "$i"
done
docker build -t linux-training-debian:latest -f debian/Dockerfile .   # shares base/'s lab-init, lab-shell, hooks
docker save linux-training-base:latest linux-training-web:latest linux-training-lamp:latest linux-training-cloud:latest \
  linux-training-devops:latest linux-training-debian:latest | docker -H "$LAB" load
docker -H "$LAB" image prune -f >/dev/null
docker -H "$LAB" images 'linux-training-*' --format '{{.Repository}}:{{.Tag}} {{.Size}}'
