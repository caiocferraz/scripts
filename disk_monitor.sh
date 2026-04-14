#!/bin/bash
# Monitor disk usage and alert if above threshold

THRESHOLD=80
ALERT_EMAIL="admin@company.com"

df -h --output=pcent,target | tail -n +2 | while read usage mount; do
    pct=${usage%\%}
    if [ "$pct" -gt "$THRESHOLD" ]; then
        echo "ALERT: $mount is at ${usage} usage" | mail -s "Disk Alert: $mount" "$ALERT_EMAIL"
        logger -t disk-monitor "WARNING: $mount at ${usage}"
    fi
done

echo "Disk check completed at $(date)"
