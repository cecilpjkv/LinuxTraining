# Training lab base: AlmaLinux 9 with systemd and the usual administration tools.
FROM almalinux/9-init
RUN dnf -y install --allowerasing --setopt=install_weak_deps=False \
      procps-ng psmisc iproute iputils bind-utils net-tools lsof vim-enhanced nano less which findutils file \
      tar gzip bzip2 unzip curl wget cronie openssh-server openssh-clients sudo util-linux passwd hostname \
      sysstat strace tree diffutils logrotate rsyslog man-db bash-completion ncurses jq nmap-ncat tcpdump \
      e2fsprogs xfsprogs rpm-build createrepo_c policycoreutils dnsmasq nftables acl python3 \
 && dnf clean all && rm -rf /var/cache/dnf \
 # units that make no sense in a container
 && systemctl mask systemd-logind.service getty@.service console-getty.service systemd-udevd.service \
      systemd-udev-trigger.service systemd-remount-fs.service dev-hugepages.mount sys-fs-fuse-connections.mount \
      systemd-hwdb-update.service systemd-firstboot.service kdump.service \
 && systemctl enable crond rsyslog sshd \
 && echo 'training' > /etc/hostname \
 && sed -i 's/^#\?Storage=.*/Storage=persistent/' /etc/systemd/journald.conf \
 && mkdir -p /var/log/journal
COPY lab-init lab-shell /usr/local/sbin/
COPY lt-shell-hooks.sh /etc/lt-shell-hooks.sh
RUN chmod 0755 /usr/local/sbin/lab-init /usr/local/sbin/lab-shell \
 && printf '\n# LinuxTraining: command history of the training terminal\n[ -r /etc/lt-shell-hooks.sh ] && . /etc/lt-shell-hooks.sh\n' >> /etc/bashrc
ENV container=docker
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/usr/local/sbin/lab-init"]
