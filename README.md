# README 

## teamspeak logwatch script
This script iterates through the latest teamspeak logfiles and captures the important parts. It's aim is to analyse only the loglines from the past day (UTC). The last step is formatting these Lines nicely to make it easy to see what happened.

### Dependencies teamspeak logwatch

* shell access
* bash > 4.2
* teamspeak 3 server
* anacron /cron
* cat

### install
Place scriptfile inside anacron `/etc/cron.daily` or run this script via `@daily` with a dedicated cronjob
 
## teamspeak xmpp push
script that iterates through the latest teamspeak loglines and captures the important parts. Main goal is to notify the receiver more often to alerting stuff happening in the logfiles.

### Dependencies teamspeak xmpp push

* shell access
* teamspeak 3 server
* anacron / cron
* bash > 4.2
* bashutils

### install
run this script via cron/anacron as often as you like the script will only send new loglines and not the previous ones.

## proftpd logwatch script
This is a script that searches through all proftpd logfiles and captures the important parts. It is configured to filter the logfiles from the past day only. The last step is emailing the results, nicely formatted, to see what happened on the proftpd server. Placed in anacron /etc/cron.daily this script will run on a daily basis.

### Dependencies proftpd logwatch

* valid Bash shell
* proftpd installation
* anacron or cron
* cat
* zcat
