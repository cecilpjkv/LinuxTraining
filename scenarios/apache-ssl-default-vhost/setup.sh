#!/bin/bash
set -e
mkdir -p /srv/www/portal
echo '<!doctype html><title>Portal</title><h1>Customer Portal</h1><p>Portal OK</p>' > /srv/www/portal/index.html
grep -q 'portal.example.test' /etc/hosts || echo '127.0.0.1 portal.example.test' >> /etc/hosts
cat > /etc/httpd/conf.d/portal.conf <<'CONF'
<VirtualHost *:80>
    ServerName portal.example.test
    DocumentRoot /srv/www/portal
    ErrorLog /var/log/httpd/portal_error.log
    CustomLog /var/log/httpd/portal_access.log combined
</VirtualHost>
<Directory /srv/www/portal>
    Require all granted
</Directory>
CONF
lt_ca() {  # lt_ca DIR: a root CA and an intermediate in DIR
  local d=$1; mkdir -p $d; cd $d
  openssl req -x509 -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout root.key -out root.crt -days 3650 -subj "/CN=Example Training Root CA" 2>/dev/null
  openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout int.key -out int.csr -subj "/CN=Example Training Intermediate" 2>/dev/null
  printf 'basicConstraints=critical,CA:true\nkeyUsage=critical,keyCertSign,cRLSign\n' > int.ext
  openssl x509 -req -in int.csr -CA root.crt -CAkey root.key -CAcreateserial -out int.crt -days 3650 -extfile int.ext 2>/dev/null
  cd - >/dev/null
}
lt_cert() {  # lt_cert CADIR NAME HOST OUTDIR [STARTDATE ENDDATE]: leaf signed by the intermediate
  local ca=$1 name=$2 host=$3 out=$4 sd=${5:-} ed=${6:-}
  mkdir -p $out
  openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout $out/$name.key -out $out/$name.csr -subj "/CN=$host" 2>/dev/null
  if [ -n "$sd" ]; then
    mkdir -p $ca/db; : > $ca/db/index.txt; [ -f $ca/db/serial ] || echo 1000 > $ca/db/serial
    printf '[ca]\ndefault_ca=d\n[d]\ndatabase=%s/db/index.txt\nserial=%s/db/serial\nnew_certs_dir=%s/db\ndefault_md=sha256\npolicy=p\nunique_subject=no\nx509_extensions=e\n[p]\ncommonName=supplied\n[e]\nsubjectAltName=DNS:%s\n' $ca $ca $ca $host > $ca/db/ca.cnf
    openssl ca -batch -notext -config $ca/db/ca.cnf -cert $ca/int.crt -keyfile $ca/int.key -startdate $sd -enddate $ed -in $out/$name.csr -out $out/$name.crt 2>/dev/null
  else
    printf 'subjectAltName=DNS:%s\n' $host > $out/$name.ext
    openssl x509 -req -in $out/$name.csr -CA $ca/int.crt -CAkey $ca/int.key -CAcreateserial -out $out/$name.crt -days 365 -extfile $out/$name.ext 2>/dev/null
  fi
  cat $out/$name.crt $ca/int.crt > $out/$name.fullchain.crt
  chmod 600 $out/$name.key
}
lt_ca /root/ca
lt_cert /root/ca portal portal.example.test /etc/pki/portal
cp /root/ca/root.crt /etc/pki/ca-root.crt
cat > /etc/httpd/conf.d/zz-portal-ssl.conf <<'CONF'
<VirtualHost *:443>
    ServerName portal.example.com
    DocumentRoot /srv/www/portal
    SSLCertificateFile /etc/pki/portal/portal.fullchain.crt
    SSLCertificateKeyFile /etc/pki/portal/portal.key
</VirtualHost>
CONF
systemctl enable --now httpd
