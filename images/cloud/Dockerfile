# Cloud hosting lab: the LAMP stack (nginx/httpd, PHP-FPM, MariaDB, WordPress, wp-cli) plus git and rsync for
# deployments and backups. Node.js 20 and npm are in the local repository (/opt/training-repo) but not installed:
# "install Node.js" works without internet access. They are modular packages, so the repository carries the nodejs:20
# module document and makes 20 the default stream (a plain `dnf install nodejs npm` works).
FROM linux-training-lamp
RUN sed -i 's/^enabled=0/enabled=1/' /etc/yum.repos.d/almalinux*.repo \
 && dnf -y install --setopt=install_weak_deps=False git-core rsync \
 && dnf -y module enable nodejs:20 \
 && dnf -y download --resolve --alldeps --destdir /opt/training-repo nodejs npm \
 && ls /opt/training-repo/nodejs-20*.rpm /opt/training-repo/npm-*.rpm \
 && dnf -y module reset nodejs \
 && python3 -c "import glob, lzma, gzip, re, sys; \
f = [p for p in glob.glob('/var/cache/dnf/appstream-*/repodata/*modules.yaml*')][0]; \
t = (lzma.open if f.endswith('.xz') else gzip.open if f.endswith('.gz') else open)(f, 'rt').read(); \
docs = [d for d in re.split(r'^---$', t, flags=re.M) if re.search(r'^document: modulemd$', d, re.M) and re.search(r'^  name: nodejs$', d, re.M) and re.search(r'^  stream: \"?20\"?$', d, re.M)]; \
assert docs; \
open('/tmp/modules.yaml', 'w').write(''.join('---' + d.rstrip().removesuffix('...').rstrip() + '\n...\n' for d in docs) + '---\ndocument: modulemd-defaults\nversion: 1\ndata:\n  module: nodejs\n  stream: \"20\"\n  profiles:\n    \"20\": [common]\n...\n')" \
 && createrepo_c -q --update /opt/training-repo \
 && modifyrepo_c --mdtype=modules /tmp/modules.yaml /opt/training-repo/repodata/ \
 && rm /tmp/modules.yaml \
 && sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/almalinux*.repo \
 && dnf clean all && rm -rf /var/cache/dnf \
 && dnf -y install --assumeno nodejs npm 2>&1 | grep -q 'nodejs.*20\.'
# PM2 (a Node process manager) vendored for offline labs: installed self-contained under /opt/pm2 so it survives
# Node staying uninstalled by default (the "install Node.js" scenarios still work). A lab's setup installs nodejs
# from the local repository and then `pm2` on PATH works. Node is installed only to build this, then removed.
RUN sed -i 's/^enabled=0/enabled=1/' /etc/yum.repos.d/almalinux*.repo \
 && dnf -y module enable nodejs:20 \
 && dnf -y install --setopt=install_weak_deps=False nodejs npm \
 && npm install -g --prefix /opt/pm2 pm2@5.4.3 \
 && ln -s /opt/pm2/bin/pm2 /usr/local/bin/pm2 \
 && npm cache clean --force \
 && dnf -y remove nodejs npm && dnf -y module reset nodejs \
 && sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/almalinux*.repo \
 && dnf clean all && rm -rf /var/cache/dnf ~/.npm \
 && test -f /opt/pm2/bin/pm2 && ! command -v node
