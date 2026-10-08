# Web stack: nginx, Apache httpd, PHP-FPM. Services are installed but disabled: each scenario's setup.sh decides what
# runs. A local repository (/opt/training-repo) holds PHP extensions that are not installed (with their
# dependencies), so "install the missing extension" works without internet access.
FROM linux-training-base
RUN dnf -y module enable php:8.2 nginx:1.24 \
 && dnf -y install --setopt=install_weak_deps=False nginx httpd mod_ssl php-fpm php-cli php-common php-opcache \
      php-mysqlnd php-pdo php-xml php-json \
 && mkdir -p /opt/training-repo \
 && dnf -y download --resolve --alldeps --destdir /opt/training-repo php-mbstring php-gd php-intl php-bcmath php-soap \
 && ls /opt/training-repo/php-mbstring-*.rpm /opt/training-repo/oniguruma-*.rpm \
 && createrepo_c -q /opt/training-repo \
 && printf '[training-local]\nname=Training local packages\nbaseurl=file:///opt/training-repo\nenabled=1\ngpgcheck=0\n' > /etc/yum.repos.d/training-local.repo \
 && sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/almalinux*.repo \
 && dnf clean all && rm -rf /var/cache/dnf
RUN systemctl disable nginx httpd php-fpm 2>/dev/null || true
