# PHP-FPM for the container scenarios (labs have no registry): Alpine's packages, listening on :9000, with `php` and
# `php-fpm` on the PATH like the official image. build.sh flattens it and tags it php:<version>-fpm-alpine.
ARG ALPINE=3.20
FROM alpine:${ALPINE}
ARG PHP=83
RUN apk add --no-cache php${PHP} php${PHP}-fpm php${PHP}-mysqli php${PHP}-pdo_mysql php${PHP}-mbstring \
 && mkdir -p /usr/local/sbin && ln -sf /usr/bin/php${PHP} /usr/local/bin/php && ln -sf /usr/sbin/php-fpm${PHP} /usr/local/sbin/php-fpm \
 && conf=$(ls -d /etc/php${PHP}) \
 && sed -i -e 's|^listen = .*|listen = 9000|' -e 's|^;clear_env = no|clear_env = no|' $conf/php-fpm.d/www.conf \
 && sed -i 's|^;error_log = .*|error_log = /proc/self/fd/2|' $conf/php-fpm.conf \
 && mkdir -p /var/www/html
WORKDIR /var/www/html
