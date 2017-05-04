#!/bin/sh

# this script tails the latest logfiles

## system variables
tslogs=/etc/teamspeak3-server_linux_amd64/logs
tmp_directory=/tmp/teamspeak
logfiles=$tmp_directory/logfiles.txt
log_selection_today=$tmp_directory/selection_today.txt


## preparations
#check if tmp directory is present
if [ ! -d "$tmp_directory" ]; then
	mkdir /tmp/teamspeak/
fi

rm $tmp_directory/{logfiles,selection_today}.txt >/dev/null 2>&1


## log selection
#picking the logfiles from the running teamspeak server for the selection
ls -t $tslogs | head -n2 | sort > $logfiles
tail -F -n1 $tslogs/$(sed -n '1p' $logfiles) >> $log_selection_today & tail -F -n1 $tslogs/$(sed -n '2p' $logfiles) >> $log_selection_today
