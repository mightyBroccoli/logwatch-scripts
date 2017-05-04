#!/bin/sh

# this script tails the latest logfiles
# */15 * * * * /PATH/teamspeak_log_crawl.sh


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

## log selection
#picking the logfiles from the running teamspeak server for the selection
ls -t $tslogs | head -n2 | sort >> $logfiles
tail -f $tslogs/$(sed -n '1p' $logfiles) -f $tslogs/$(sed -n '2p' $logfiles) | grep -E $(date -d "today" '+%Y-%m-%d') >> $log_selection_today
