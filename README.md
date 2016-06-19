# README #

### Dependencies proftpd logwatch ###

* valid Bash shell
* proftpd installation
* anacron or cron
* cat
* zcat

### proftpd logwatch script ###

This is a script that searches through all proftpd logfiles and captures the important parts. It is configured to filter the logfiles from the past day only. The last step is emailing the results, nicely formatted, to see what happened on the proftpd server. Placed in anacron /etc/cron.daily this script will run on a daily basis. 



### Dependencies teamspeak logwatch ###

* valid Bash shell
* teamspeak installation
* anacron or cron
* cat

### teamspeak logwatch script ###

This is a script that searches through all teamspeak logfiles and captures the important parts. It is configured to analyse the logfiles from the past day only. The last step is sending these Lines, nicely formatted, to easily see what happened on the teamspeak server. Placed in anacron /etc/cron.daily this script will run on a daily basis. 