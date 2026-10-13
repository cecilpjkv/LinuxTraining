#!/bin/sh
set -e
mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld /var/lib/mysql
if [ ! -d /var/lib/mysql/mysql ]; then
  echo "Initializing database files"
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db >/dev/null
  {  # --bootstrap: one statement per line
    echo "FLUSH PRIVILEGES;"  # --bootstrap starts without the grant tables
    echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';"
    echo "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';"
    echo "GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;"
    [ -n "$MARIADB_DATABASE" ] && echo "CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;"
    [ -n "$MARIADB_USER" ] && echo "CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';"
    [ -n "$MARIADB_USER" ] && echo "GRANT ALL ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';"
    echo "FLUSH PRIVILEGES;"
  } > /tmp/init.sql
  mariadbd --user=mysql --bootstrap < /tmp/init.sql
  rm -f /tmp/init.sql
fi
echo "Starting MariaDB $(mariadbd --version | awk '{print $3}')"
# the entrypoint stays the container's main process (root): `docker exec` must open its namespaces, which a lab
# (no CAP_SYS_PTRACE) cannot do for a process of another user such as mariadbd
mariadbd --user=mysql "$@" &
pid=$!
trap 'kill -TERM $pid' TERM INT
wait $pid
trap - TERM INT
wait $pid
