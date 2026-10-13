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
