# Web stack + MariaDB.
FROM linux-training-web
RUN sed -i 's/^enabled=0/enabled=1/' /etc/yum.repos.d/almalinux*.repo \
 && dnf -y install --setopt=install_weak_deps=False mariadb-server mariadb \
 && sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/almalinux*.repo && sed -i 's/^enabled=0/enabled=1/' /etc/yum.repos.d/training-local.repo \
 && dnf clean all && rm -rf /var/cache/dnf \
 && systemctl disable mariadb 2>/dev/null; true
