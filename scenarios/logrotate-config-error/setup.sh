#!/bin/bash
set -e
mkdir -p /var/log/payments && echo start > /var/log/payments/payments.log
printf '/var/log/payments/*.log {\n    dialy\n    rotate 14\n    compress\n    missingok\n}\n' > /etc/logrotate.d/payments
