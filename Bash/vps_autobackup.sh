#!/bin/bash

DATUM=$(date +%F)
TID=$(date "+%Y-%m-%d %H:%M:%S")

STATE=$(virsh domstate Skol-VPS-01)

if [ "$STATE" == "running" ]; then
    if virsh snapshot-create-as --domain Skol-VPS-01 --name "snap-$DATUM" --description "Automatisk backup" --disk-only --atomic; then
        echo "SUCCESS + ny snapshot (snap-$DATUM) i virsh snapshot-list $TID" >> /var/log/vps_maintenance.log
        echo "SUCCESS + ny snapshot (snap-$DATUM)"
    else 
        echo "Snapshot misslyckades (snap-$DATUM)" >> /var/log/vps_maintenance.log
        echo "Snapshot misslyckades"
    fi
else 
    echo "WARNING, ingen ny snapshot $TID" >> /var/log/vps_maintenance.log
    echo "WARNING, ingen ny snapshot $TID" 
fi
