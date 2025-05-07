#!/bin/bash

# Set timezone
if [ -n "$TZ" ]; then
    ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
fi

# Check if rclone config file exists
for file in /root/.config/rclone/*; do
    echo "Processing file: $file"
done

# Initialize cron
echo "Initializing cron..."
touch /var/log/cron.log

# Generate cron jobs from environment variables
echo "Generating cron jobs..."
echo "Generating cron jobs..." > /etc/crontabs/root

# Process environment variables
env | while IFS= read -r line; do
    if [[ "$line" =~ ^BACKUP_[0-9]+_SCHEDULE= ]]; then
        backup_num=$(echo "$line" | cut -d'_' -f2)
        var_prefix="BACKUP_${backup_num}_"
        schedule=$(env | grep "${var_prefix}SCHEDULE" | cut -d'=' -f2-)
        source_dir=$(env | grep "${var_prefix}SOURCE" | cut -d'=' -f2-)
        destination=$(env | grep "${var_prefix}DESTINATION" | cut -d'=' -f2-)
        retention=$(env | grep "${var_prefix}RETENTION" | cut -d'=' -f2-)
        shoutrrr_url=$(env | grep "${var_prefix}SHOUTRRR_URL" | cut -d'=' -f2-)
        name=$(env | grep "${var_prefix}NAME" | cut -d'=' -f2-)

        if [ -z "$schedule" ] || [ -z "$source_dir" ] || [ -z "$destination" ]; then
            echo "Error: Backup ${backup_num} is missing required parameters"
            exit 1
        fi

        echo "Adding backup job ${name} ${backup_num}: ${schedule} ${source_dir} → ${destination} (Retention: ${retention:-"unlimited"})"
        echo "${schedule} /app/backup-scripts/backup.sh \"${source_dir}\" \"${destination}\" \"${retention}\" \"${shoutrrr_url}\" \"${name}\" >> /var/log/cron.log 2>&1" >> /etc/crontabs/root
    fi
done

# Start cron in foreground with proper logging
echo "Starting cron..."
crond -f -s /var/log/cron.log &

# Keep container alive and show logs
tail -f /var/log/cron.log