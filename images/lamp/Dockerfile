# Web stack + MariaDB.
FROM linux-training-web
RUN sed -i 's/^enabled=0/enabled=1/' /etc/yum.repos.d/almalinux*.repo \
 && dnf -y install --setopt=install_weak_deps=False mariadb-server mariadb \
 && sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/almalinux*.repo \
 && sed -i 's/^enabled=0/enabled=1/' /etc/yum.repos.d/training-local.repo \
 && dnf clean all && rm -rf /var/cache/dnf
RUN systemctl disable mariadb 2>/dev/null || true
# WordPress (pinned) and wp-cli for the WordPress scenarios: labs have no internet, so the code ships in the image
RUN curl -fsSL https://wordpress.org/wordpress-6.6.2.tar.gz | tar -xz -C /opt \
 && test -f /opt/wordpress/wp-settings.php \
 && curl -fsSL -o /usr/local/bin/wp https://github.com/wp-cli/wp-cli/releases/download/v2.11.0/wp-cli-2.11.0.phar \
 && chmod 755 /usr/local/bin/wp \
 && php /usr/local/bin/wp --allow-root --version
