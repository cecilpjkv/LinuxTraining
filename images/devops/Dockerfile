# DevOps lab: git, Ansible and a container engine. Podman runs as a system service (podman.socket: started by systemd,
# which keeps the capabilities the technician's shell drops) behind the real docker CLI and compose plugin, so
# `docker ...` and `docker compose ...` work as on a Docker host (/run/docker.sock points at Podman's socket).
# Scenarios that run containers set `nested_containers: true` (the engine needs the lab's network sysctls).
# Labs have no internet: the container images scenarios use ship in /opt/lt-images (loaded by setup.sh), and a local
# repository (/opt/training-repo) holds the packages playbooks install.
FROM linux-training-base
RUN dnf -y install --setopt=install_weak_deps=False git make ansible-core podman skopeo rsync \
 && dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo \
 && dnf -y install --setopt=install_weak_deps=False docker-ce-cli docker-compose-plugin \
 && mkdir -p /opt/training-repo \
 && dnf -y download --resolve --alldeps --destdir /opt/training-repo nginx \
 && createrepo_c -q /opt/training-repo \
 && printf '[training-local]\nname=Training local packages\nbaseurl=file:///opt/training-repo\nenabled=1\ngpgcheck=0\n' > /etc/yum.repos.d/training-local.repo \
 && sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/almalinux*.repo /etc/yum.repos.d/docker-ce.repo \
 && dnf clean all && rm -rf /var/cache/dnf
# Podman inside a lab: vfs storage (overlay on the lab's own overlay root needs fuse), no session keyrings and no
# pivot_root (both refused by the lab's seccomp profile)
RUN printf '[storage]\ndriver = "vfs"\nrunroot = "/run/containers/storage"\ngraphroot = "/var/lib/containers/storage"\n' > /etc/containers/storage.conf \
 && printf '[containers]\nkeyring = false\n\n[engine]\nno_pivot_root = true\n' > /etc/containers/containers.conf \
 && printf 'L /run/docker.sock - - - - /run/podman/podman.sock\n' > /usr/lib/tmpfiles.d/lt-docker-sock.conf \
 && printf '# the podman CLI talks to the system service too (the shell itself cannot mount)\nexport CONTAINER_HOST=unix:///run/podman/podman.sock\n' > /etc/profile.d/lt-podman.sh \
 && systemctl enable podman.socket
RUN mkdir -p /opt/lt-images \
 && skopeo copy -q docker://docker.io/library/busybox:1.36 docker-archive:/opt/lt-images/busybox.tar:docker.io/library/busybox:1.36 \
 && skopeo copy -q docker://docker.io/library/nginx:1.27-alpine docker-archive:/opt/lt-images/nginx.tar:docker.io/library/nginx:1.27-alpine \
 && ls -la /opt/lt-images
# PHP-FPM 8.1/8.3 and MariaDB 10.11.14/10.11.18, built from Alpine by build.sh (images/containers): one archive per
# image, under its full registry name (docker save keeps short names, which Podman would load as localhost/...)
RUN --mount=type=bind,source=lt-images,target=/tmp/lt \
    for t in php:8.1-fpm-alpine php:8.3-fpm-alpine mariadb:10.11.14 mariadb:10.11.18; do \
      skopeo copy -q docker-archive:/tmp/lt/${t%%:*}.tar:$t docker-archive:/opt/lt-images/$(echo $t | tr : -).tar:docker.io/library/$t || exit 1; \
    done \
 && ls -la /opt/lt-images
# Ansible labs: the collections playbooks use (offline), and what target servers install from the local repository
# (PHP-FPM, MariaDB + PyMySQL for community.mysql, firewalld, Certbot with its nginx plugin from EPEL). Pebble, Let's
# Encrypt's test ACME server, gives Certbot real certificate issuance without internet (acme-ca.service, disabled).
RUN ansible-galaxy collection install -p /usr/share/ansible/collections ansible.posix community.general community.mysql community.crypto \
 && sed -i 's/^enabled=0/enabled=1/' /etc/yum.repos.d/almalinux*.repo \
 && dnf -y install --setopt=install_weak_deps=False epel-release \
 && dnf -y download --resolve --alldeps --destdir /opt/training-repo php-fpm php-cli php-mysqlnd php-mbstring php-opcache \
      mariadb-server mariadb python3-PyMySQL firewalld httpd certbot python3-certbot-nginx \
 && ls /opt/training-repo/certbot-*.rpm /opt/training-repo/firewalld-*.rpm /opt/training-repo/mariadb-server-*.rpm \
 && createrepo_c -q --update /opt/training-repo \
 && dnf -y remove epel-release && rm -f /etc/yum.repos.d/epel*.repo \
 && sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/almalinux*.repo \
 && dnf clean all && rm -rf /var/cache/dnf \
 && curl -fsSL https://github.com/letsencrypt/pebble/releases/download/v2.6.0/pebble-linux-amd64.tar.gz \
    | tar -xzO pebble-linux-amd64/linux/amd64/pebble > /usr/local/bin/pebble \
 && chmod 755 /usr/local/bin/pebble && /usr/local/bin/pebble -version
