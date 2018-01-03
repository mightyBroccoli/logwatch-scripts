[![Codacy Badge](https://api.codacy.com/project/badge/Grade/2e2526c5266848f8ae3e03a87079bc49)](https://www.codacy.com/app/nico.wellpott/logwatch-scripts?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=mightyBroccoli/logwatch-scripts&amp;utm_campaign=Badge_Grade)

# TeamSpeak3 Logwatch Script
Script which iterates through the latest teamspeak logfiles and captures the important parts. Main goal is to filter relevant loglines from the past day (UTC). Finally the selected lines are being formatted nicely, so it is easy to see what happened.
There are two possible notification modes:
- E-Mail
- XMPP Push

## Dependencies
For Mail notifications:
* shell access
* bash > 4.2
* teamspeak 3 server
* anacron / cron

Additional dependencies for XMPP Push:
* bashutils
* sendxmpp

## Installation
Copy the provided user.config.sample to directory specified as $tmp_directory and name it .user.config. Place all the needed info in the .user.config file.
Place scriptfile inside anacron `/etc/cron.daily` or run this script via `@daily` with a dedicated cronjob
`@daily /PATH/TO/SCRIPT/teamspeak_log_daily_mail`

## Example for Email notifications
This is just an example how the logmail could look like. The script will only send those parts which actually hold data.
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

## Example for XMPP Push
This is just an example for a notification pushed via XMPP. The script will only send notifications if there is content to notify about.
```
---- Group change ----
--- added ---
2017-05-12 18:56:38.609377|INFO    |VirtualServer |1  |client (id:USER ID) was added to servergroup 'SERVERGROUP NAME'(id:SERVERGROUP ID) by client 'USERNAME'(id:USER ID)
2017-05-12 22:09:01.658969|INFO    |VirtualServer |1  |client (id:USER ID) was added to servergroup 'SERVERGROUP NAME'(id:SERVERGROUP ID) by client 'USERNAME'(id:USER ID)
---- Group change End ----
```

## Donations
If somebody is that enthusiastic about this project and does want to donate me some coffee, I would be really pleased and happy. I provide two possibilities: PayPal and Bitcoin
<div>
  <a href="bitcoin:1QJZTWenBvdLWTUachpLLd2dLXAZMGeU87">
  <img src="https://magicbroccoli.de/images/bitcoin_qr.png" ></a>
  <p>1QJZTWenBvdLWTUachpLLd2dLXAZMGeU87</p>
</div>

[![Donate with PayPal](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=DXUYBYN2XCW9U)
