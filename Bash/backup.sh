#!/bin/bash

SOURCE=$1
BACKUP_FOLDER=$2
DATE=$(date +%Y-%m-%d_%H%M%S)
FILE_NAME="backup_$DATE.tar.gz"

if [ -d "$SOURCE" ]; then
    if (tar -czf "$BACKUP_FOLDER/$FILE_NAME" "$SOURCE"); then
        echo "[$DATE] SUCCESS: Backup saved as: $FILE_NAME" >> /var/log/backup_history.log
    else
        echo "[$DATE] ERROR: Backup failed" >> /var/log/backup_history.log
    fi
else echo "[$DATE] ERROR: Source folder not found" >> /var/log/backup_history.log
fi

    