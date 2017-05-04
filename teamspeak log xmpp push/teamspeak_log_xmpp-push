#!/bin/sh

## Usage
# edit all the user variables and possibly the tslog path to fit your needs
# run this script every x minutes to send the lines accumulated in the log files via cron eg
# */15 * * * * /PATH/teamspeak_log_xmpp-push.sh


## user variables
xmpp_sender=FROM@SERVER.TLD
xmpp_sender_pw=PASSWORD
xmpp_server=SERVER.TLD
xmpp_reciever=TO@ANOTHERSERVER.TLD
ressource=RANDOMSHIT
tslogs=/etc/teamspeak3-server_linux_amd64/logs

# selection variables
tmp_directory=/tmp/teamspeak
logfiles=$tmp_directory/logfiles.txt
log_selection_today=$tmp_directory/selection_today.txt


# comppositon variables
working_file=$tmp_directory/working.txt
composition1=$tmp_directory/composition1.txt
composition2=$tmp_directory/composition2.txt
server=$tmp_directory/server.txt
complaint=$tmp_directory/complaint.txt
ban=$tmp_directory/ban.txt
kick=$tmp_directory/kick.txt
groupchange=$tmp_directory/groupchange.txt
channel=$tmp_directory/channel.txt
#permissions=$tmp_directory/permissions.txt


## todo


## functions
pushstuff()
{
	# xmpp push function with variable message
	sendxmpp -u $xmpp_sender -p $xmpp_sender_pw -j $xmpp_server --tls --resource $ressource $xmpp_reciever --message $1
}

clearcomp()
{
	# remove the composition files
	rm $composition1 $composition2 >/dev/null 2>&1
}


## preparations
#deleting possible old content
rm $tmp_directory/{working,composition1,composition2,server,groupchange,complaint,ban,kick,channel}.txt >/dev/null 2>&1

# move the current logfile to the working file
mv $log_selection_today $working_file

## server ##
cat $working_file | grep -E 'ServerMain|stopped|Accounting|Warning|ERROR' >> $composition1
echo -e "---- Server ----\n" >> $composition2
cat $composition1 | sort -M -k 2 >> $composition2
echo -e "---- Server End ----\n" >> $composition2

#paste the shit into the file and remove the tmp files afterwords
if [[ -s $composition1 ]]; then
	cat $composition2 > $server
	pushstuff $server
fi
clearcomp

## Complaint ##
cat $working_file | grep complaint* >> $composition1

echo -e "---- Complaint ----\n" >> $composition2
cat $composition1 >> $composition2
echo -e "---- Complaint End ----\n" >> $composition2

#paste the shit into the file and remove the tmp files afterwords
if [[ -s $composition1 ]]; then
	cat $composition2 > $complaint
	pushstuff $complaint
fi
clearcomp

## Ban ##
cat $working_file | grep -E 'ban added|BanManager' >> $composition1
echo -e "---- Ban ----\n" >> $composition2
cat $composition1 | sort -M -k 2 >> $composition2
echo -e "---- Ban End ----\n" >> $composition2

#paste the shit into the file and remove the tmp files afterwords
if [[ -s $composition1 ]]; then
	cat $composition2 > $ban
fi
clearcomp

## Kick ## 
cat $working_file | grep "reason 'invokerid" >> $composition1

echo -e "---- Kick ----\n" >> $composition2
cat $composition1 >> $composition2
echo -e "---- Kick End ----\n" >> $composition2

#paste the shit into the file and remove the tmp files afterwords
if [[ -s $composition1 ]]; then
	cat $composition2 > $kick
	pushstuff $kick
fi
clearcomp

## Group change ##
echo -e "---- Group change ----\n" > $composition2
echo -e "--- added ---\n" >> $composition2
cat $working_file | grep "was added to servergroup" > $composition1
cat $composition1 >> $composition2
echo -e "--- removed ---\n" >> $composition2
cat $working_file | grep "was removed from servergroup" > $composition1
cat $composition1 >> $composition2
echo -e "---- Group change End ----\n" >> $composition2

#paste the shit into the file
if [[ -s $composition1 ]]; then
	cat $composition2 >> $groupchange
	pushstuff $groupchange
fi
clearcomp

## Ban ##
cat $working_file | grep -E 'channel|VirtualServerBase' > $composition1
echo -e "---- Channel ----\n" > $composition2
cat $composition1 | sort -M -k 2 >> $composition2
echo -e "---- Channel End ----\n" >> $composition2

#paste the shit into the file and remove the tmp files afterwords
if [[ -s $composition1 ]]; then
	cat $composition2 > $channel
	pushstuff $channel
fi
clearcomp
