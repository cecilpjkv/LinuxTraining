# Debian 12 lab (APT/dpkg scenarios) with systemd, built like linux-training-base (context: images/, for the shared
# lab-init, lab-shell and terminal hooks). nginx is installed one point release behind: a local APT repository
# (/opt/apt-repo, the only source: labs have no internet) holds the newer nginx and openssl, so "check, update,
# upgrade the designated package" works as on a real server.
FROM debian:12
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends systemd systemd-sysv dbus procps psmisc iproute2 iputils-ping \
      dnsutils net-tools lsof vim-tiny nano less file tar gzip unzip curl wget ca-certificates cron openssh-server \
      openssh-client sudo util-linux passwd hostname strace tree diffutils logrotate rsyslog man-db bash-completion \
      ncurses-term jq netcat-openbsd python3 bc apt-utils \
 && apt-get install -y --no-install-recommends --allow-downgrades nginx=1.22.1-9+deb12u9 nginx-common=1.22.1-9+deb12u9 \
      openssl=3.0.20-1~deb12u2 libssl3=3.0.20-1~deb12u2 \
 && mkdir -p /opt/apt-repo && cd /opt/apt-repo \
 && apt-get download nginx=1.22.1-9+deb12u10 nginx-common=1.22.1-9+deb12u10 openssl=3.0.22-1~deb12u1 libssl3=3.0.22-1~deb12u1 \
 && apt-ftparchive packages . > Packages && gzip -k Packages \
 && apt-ftparchive -o APT::FTPArchive::Release::Origin=Training -o APT::FTPArchive::Release::Suite=bookworm release . > Release \
 && rm -f /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list \
 && echo 'deb [trusted=yes] file:/opt/apt-repo ./' > /etc/apt/sources.list.d/training-local.list \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /var/cache/apt/archives/*.deb \
 && systemctl mask systemd-logind.service getty@.service console-getty.service systemd-udevd.service \
      systemd-udev-trigger.service systemd-remount-fs.service dev-hugepages.mount sys-fs-fuse-connections.mount \
      systemd-hwdb-update.service systemd-firstboot.service \
 && systemctl enable cron rsyslog ssh \
 && systemctl disable nginx \
 && echo 'training' > /etc/hostname \
 && printf 'PermitRootLogin yes\n' > /etc/ssh/sshd_config.d/10-permitrootlogin.conf \
 && mkdir -p /etc/systemd/journald.conf.d && printf '[Journal]\nStorage=persistent\n' > /etc/systemd/journald.conf.d/lt.conf \
 && mkdir -p /var/log/journal
COPY base/lab-init base/lab-shell /usr/local/sbin/
COPY base/lt-shell-hooks.sh /etc/lt-shell-hooks.sh
RUN chmod 0755 /usr/local/sbin/lab-init /usr/local/sbin/lab-shell \
 && printf '\n# LinuxTraining: command history of the training terminal\n[ -r /etc/lt-shell-hooks.sh ] && . /etc/lt-shell-hooks.sh\n' >> /etc/bash.bashrc
ENV container=docker
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/usr/local/sbin/lab-init"]
