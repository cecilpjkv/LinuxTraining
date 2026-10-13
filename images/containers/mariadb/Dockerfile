# MariaDB for the container scenarios: Alpine's package with an entrypoint that, like the official image, initialises
# an empty data directory from MARIADB_ROOT_PASSWORD / MARIADB_DATABASE / MARIADB_USER / MARIADB_PASSWORD.
# build.sh flattens it and tags it mariadb:<exact version>.
ARG ALPINE=3.20
FROM alpine:${ALPINE}
RUN apk add --no-cache mariadb mariadb-client \
 && mkdir -p /run/mysqld /var/lib/mysql && chown mysql:mysql /run/mysqld /var/lib/mysql \
 && printf '[mysqld]\nbind-address=0.0.0.0\nskip-networking=0\nuser=mysql\ndatadir=/var/lib/mysql\n' > /etc/my.cnf.d/zz-container.cnf
COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh
