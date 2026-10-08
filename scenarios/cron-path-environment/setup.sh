#!/bin/bash
set -e
mkdir -p /opt/reporting/bin /var/reports
printf '#!/bin/bash\necho "sales report $(date +%%F)"\n' > /opt/reporting/bin/render-report
chmod 755 /opt/reporting/bin/render-report
printf '#!/bin/bash\n# sales report: uses the reporting tools\nrender-report > /var/reports/sales-$(date +%%F-%%H).txt\n' > /usr/local/bin/sales-report
chmod 755 /usr/local/bin/sales-report
echo 'export PATH=$PATH:/opt/reporting/bin' > /etc/profile.d/reporting.sh
printf 'MAILTO=""\n0 * * * * root /usr/local/bin/sales-report\n' > /etc/cron.d/sales-report
