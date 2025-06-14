#!/bin/bash

SOURCE=$1
DESTINATION=$2
RETENTION_COUNT=$3
SHOUTRRR_URL=$4
NAME=$5

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="/tmp/backup_${TIMESTAMP}.log"
DEST_DIR="${DESTINATION}/${TIMESTAMP}"

echo "Starting backup: ${SOURCE} → ${DEST_DIR}"
echo "Backup started at $(date)" > "$LOG_FILE"

# Verify remote exists
if ! rclone listremotes | grep -q "^${DESTINATION%%:*}:$"; then
    echo "ERROR: Rclone remote '${DESTINATION%%:*}' not configured!" | tee -a "$LOG_FILE"
    exit 1
fi

# Create timestamped backup directory
rclone mkdir "${DEST_DIR}" >> "$LOG_FILE" 2>&1

# Perform backup
rclone copy -vvv "${SOURCE}" "${DEST_DIR}" --log-file="$LOG_FILE" --stats-one-line
EXIT_CODE=$?

# Apply retention policy if specified
if [ -n "$RETENTION_COUNT" ] && [ "$RETENTION_COUNT" -gt 0 ]; then
    echo "Applying retention policy (keep last ${RETENTION_COUNT} backups)" >> "$LOG_FILE"

    # Get list of backups sorted by date (newest first)
    BACKUP_LIST=$(rclone lsd "${DESTINATION}" | awk '{print $NF}' | sort -r)

    # Count backups and delete older ones
    COUNT=0
    echo "$BACKUP_LIST" | while read -r backup_dir; do
        COUNT=$((COUNT + 1))
        if [ "$COUNT" -gt "$RETENTION_COUNT" ]; then
            echo "Deleting old backup: ${backup_dir}" >> "$LOG_FILE"
            rclone purge "${DESTINATION}/${NAME}/${backup_dir}" >> "$LOG_FILE" 2>&1
        fi
    done
fi

# Notification logic
if [ $EXIT_CODE -eq 0 ]; then
    STATUS="Successful"
else
    STATUS="Failed with error code $EXIT_CODE"
fi

MESSAGE=$(printf "Backup %s\n Source: %s\n Destination: %s\n Retention: %s rotation" \
  "$STATUS" "$SOURCE" "$DEST_DIR" "${RETENTION_COUNT:-No}")

if [ -n "$SHOUTRRR_URL" ]; then
    echo "Sending notification..." >> "$LOG_FILE"
    /usr/local/bin/shoutrrr send --message "${MESSAGE}" --url "${SHOUTRRR_URL}" --title "Name: ${NAME}" >> "$LOG_FILE" 2>&1
fi

echo "Backup completed: ${STATUS}"
exit $EXIT_CODE