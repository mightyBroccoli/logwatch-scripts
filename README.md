# README 
## teamspeak logwatch script
Script that iterates through the latest teamspeak logfiles and captures the important parts. Main goal is to filter out only those loglines from the past day (UTC). The last step is formatting these Lines nicely, to make it easy to see what happened.

### Dependencies teamspeak logwatch
* shell access
* bash > 4.2
* teamspeak 3 server
* anacron /cron
* cat

### install
Copy the provided user.config.sample to directory specified as $tmp_directory and name it .user.config. Place all the needed info in the .user.config file.
Place scriptfile inside anacron `/etc/cron.daily` or run this script via `@daily` with a dedicated cronjob
`@daily /PATH/TO/SCRIPT/teamspeak_log_daily_mail`

### example
As an example this could be a logmail. I anonymized the content. The script will only send those parts which actually hold data.
```
---------------------- Teamspeak -------------------------
-------------------- Server -----------------------
Status : ● ts3server.service - TeamSpeak 3 Server
   Loaded: loaded (/etc/systemd/system/ts3server.service; enabled)
  Active: active (running) since So 2017-04-16 09:10:23 CEST; 3 weeks 5 days ago
Main PID: 3305 (ts3server)
  CGroup: /system.slice/ts3server.service
       └─3305 ./ts3server inifile=ts3server.ini
------------------ Server End ---------------------
-------------------- Kick ------------------------
2017-05-12 13:10:16.120599|INFO    |VirtualServerBase|1  |client disconnected 'USER'(id:USERID) reason 'invokerid=INVOKERID invokername=INVOKERNAME invokeruid=INVOKERUID reasonmsg=MESSAGE'
------------------ Kick End ----------------------
------------------- Permission --------------------
2017-05-12 22:04:44.280211|INFO    |VirtualServer |1  |permission 'PERMISSION NAME' with values (value:-1, negated:0, skipchannel:0) was added by 'USERNAME'(id:USERID) to servergroup 'SERVERGROUP NAME'(id:SERVERGROUP ID)
----------------- Permission End ------------------
-------------------- Teamspeak End -----------------------
```

## teamspeak xmpp push
Script that iterates through the latest teamspeak loglines and captures the important parts. Main goal is to  get the notification about important logevents more often.

### Dependencies teamspeak xmpp push
* shell access
* bash > 4.2
* teamspeak 3 server
* anacron / cron
* bashutils
* sendxmpp

### install
Copy the provided user.config.sample to directory specified as $tmp_directory and name it .user.config. Place all the needed info in the .user.config file.
run this script via cron/anacron as often as you like. The script will only use new loglines and not the previous ones in consideration for natification.
As an example to run it every 15 mins via cron `*/15 * * * * /PATH/TO/SCRIPT/teamspeak_log_xmpp-push.sh`

### example
As an example for a notification pushed via xmpp. I anonymized the content. The script will only send if there is content.
```
---- Group change ----
--- added ---
2017-05-12 18:56:38.609377|INFO    |VirtualServer |1  |client (id:USER ID) was added to servergroup 'SERVERGROUP NAME'(id:SERVERGROUP ID) by client 'USERNAME'(id:USER ID)
2017-05-12 22:09:01.658969|INFO    |VirtualServer |1  |client (id:USER ID) was added to servergroup 'SERVERGROUP NAME'(id:SERVERGROUP ID) by client 'USERNAME'(id:USER ID)
---- Group change End ----
```
## proftpd logwatch script
This is a script that searches through all proftpd logfiles and captures the important parts. It is configured to filter the logfiles from the past day only. The last step is emailing the results, nicely formatted, to see what happened on the proftpd server. Placed in anacron /etc/cron.daily this script will run on a daily basis.

### Dependencies proftpd logwatch

* valid Bash shell
* proftpd installation
* anacron or cron
* cat
* zcat
