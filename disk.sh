#!/usr/bin/bash

scsisum=`ls -1 /sys/class/scsi_host/host*|wc -l`

for ((i=0;i<${scsisum};i++))
do
    echo "- - -" > /sys/class/scsi_host/host${i}/scan
done

