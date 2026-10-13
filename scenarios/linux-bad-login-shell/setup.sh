#!/bin/bash
set -e
id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash deploy
# a legitimate scheduled job for deploy (must keep working)
install -d -o deploy -g deploy /home/deploy/bin
printf '#!/bin/bash\necho ok\n' > /home/deploy/bin/nightly.sh
chmod 755 /home/deploy/bin/nightly.sh; chown deploy: /home/deploy/bin/nightly.sh
# the break: the login shell was pointed at a shell that is not installed
usermod -s /usr/local/bin/devops-shell deploy
