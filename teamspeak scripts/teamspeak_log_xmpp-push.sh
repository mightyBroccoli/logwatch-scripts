#!/bin/bash
#
## Version 0.0.1
#
#
## Dependencies
#
# shell access
# teamspeak 3 server
# anacron / cron
# bash > 4.2
# bashutils
#
#
## Usage
# edit all the user variables and possibly the tslog path to fit your needs
# run this script every x minutes to send the lines accumulated in the log files via cron eg
# */x * * * * /PATH/teamspeak_log_xmpp-push.sh


## user variables
xmpp_username=FROM					# just the username not the complete jid
xmpp_password=PASSWORD
xmpp_server=SERVER.TLD
xmpp_recipient=TO@ANOTHERSERVER.TLD	# the complete jid
ressource=RANDOMSHIT				# some random string to indetify
tslogs=/etc/teamspeak3-server_linux_amd64/logs
tmp_directory=/tmp/teamspeak

# selection variables
logfiles=$tmp_directory/logfiles.txt
log_selection_today_unsorted=$tmp_directory/selection_today_unsorted.txt
log_selection_today=$tmp_directory/selection_today_sorted.txt
log_removed_old=$tmp_directory/selection_removed_old.txt
log_history=$tmp_directory/today_history.txt
currentday=$(date -u '+%Y-%m-%d')

# comppositon variables
composition1=$tmp_directory/composition1.txt
composition2=$tmp_directory/composition2.txt
composition3=$tmp_directory/composition3.txt
server=$tmp_directory/server.txt
complaint=$tmp_directory/complaint.txt
ban=$tmp_directory/ban.txt
kick=$tmp_directory/kick.txt
groupchange=$tmp_directory/groupchange.txt
channel=$tmp_directory/channel.txt
#permissions=$tmp_directory/permissions.txt


## todo
# code cleaning


## functions
pushstuff()
{
	# xmpp push function with variable message
	sendxmpp -u $xmpp_username -p $xmpp_password -j $xmpp_server --tls --resource $ressource $xmpp_recipient --message "$1"
}

clearcomp()
{
	# remove the composition files
	rm $composition1 $composition2 $composition3 >/dev/null 2>&1
}


## preparations
#check if tmp directory is present if not create it
if [ ! -d "$tmp_directory" ]; then
	mkdir /tmp/teamspeak/
fi

#is the history relevant
#check if date file is present
if [ ! -f "$tmp_directory/date.txt" ]; then
	date -u '+%Y-%m-%d' > $tmp_directory/date.txt
fi
if [ ! "$currentday" = "$(cat $tmp_directory/date.txt)" ]; then
	#they are not the same remove the old history
	rm $log_history
	#set the new date inside the date file
	date -u '+%Y-%m-%d' > $tmp_directory/date.txt
fi

#deleting possible old content
rm $tmp_directory/{logfiles,selection_today_unsorted,selection_today_sorted,selection_removed_old,composition1,composition2,server,complaint,ban,kick,groupchange,channel}.txt >/dev/null 2>&1

## log file selection
#get the currently used logfiles
ls -t $tslogs | head -n2 | sort > $logfiles

#from the $logfiles get everything from today
grep "$(date -u '+%Y-%m-%d')" "$tslogs/$(sed -n '1p' $logfiles)" > $log_selection_today_unsorted
grep "$(date -u '+%Y-%m-%d')" "$tslogs/$(sed -n '2p' $logfiles)" >> $log_selection_today_unsorted

# sort logentries
sort $log_selection_today_unsorted > $log_selection_today

#if  $log_history file exists append if not create it
if [ -s  $log_history ]; then
	#it does exist
	grep -v -F -x -f $log_history $log_selection_today  > $log_removed_old
	cat $log_removed_old >> $log_history
else
	#it doesn't exist
	cat $log_selection_today > $log_history
	# first run of the day history = log_removed_old
	cat $log_selection_today > $log_removed_old
fi


#################################################


## server ##
grep -E 'ServerMain|stopped|Accounting|Warning|ERROR' $log_removed_old  >> $composition1

{	echo -e "---- Server ----\n"
	sort $composition1
	echo -e "---- Server End ----" 
} >> $composition2

#paste the shit into the file and remove the tmp files afterwords
if [ -s $composition1 ]; then
	cat $composition2 > $server
	pushstuff $server
fi
clearcomp

## Complaint ##
grep "^complaint" $log_removed_old >> $composition1

{	echo -e "---- Complaint ----\n"
	cat $composition1
	echo -e "---- Complaint End ----"
} >> $composition2

#paste the shit into the file and remove the tmp files afterwords
if [ -s $composition1 ]; then
	cat $composition2 > $complaint
	pushstuff $complaint
fi
clearcomp

## Ban ##
grep -E 'ban added|BanManager' $log_removed_old  >> $composition1
{	echo -e "---- Ban ----\n"
	sort $composition1
	echo -e "---- Ban End ----"
}>> $composition2

#paste the shit into the file and remove the tmp files afterwords
if [ -s $composition1 ]; then
	cat $composition2 > $ban
fi
clearcomp

## Kick ## 
grep "reason 'invokerid" $log_removed_old >> $composition1

{	echo -e "---- Kick ----\n"
	cat $composition1
	echo -e "---- Kick End ----"
} >> $composition2

#paste the shit into the file and remove the tmp files afterwords
if [ -s $composition1 ]; then
	cat $composition2 > $kick
	pushstuff $kick
fi
clearcomp

## Group change ##
echo -e "---- Group change ----\n" >> $composition2

grep "was added to servergroup" $log_removed_old > $composition1
if [ -s $composition1 ]; then
	{
		echo -e "--- added ---\n"
		cat $composition1
	} >> $composition2
	cat $composition1 >> $composition3
fi

grep "was removed from servergroup" $log_removed_old > $composition1
if [ -s $composition1 ]; then
	{
		echo -e "--- removed ---\n"
		cat $composition1
	} >> $composition2
	cat $composition1 >> $composition3
fi

echo -e "---- Group change End ----" >> $composition2

#paste the shit into the file
if [ -s $composition3 ]; then
	cat $composition2 >> $groupchange
	pushstuff $groupchange
fi
clearcomp

## Channel ##
grep channel $log_removed_old > $composition1
grep VirtualServerBase $composition1 > $composition2
cat $composition2 > $composition1

{	echo -e "---- Channel ----\n"
	sort $composition1
	echo -e "---- Channel End ----"
} > $composition2

#paste the shit into the file and remove the tmp files afterwords
if [ -s $composition1 ]; then
	cat $composition2 > $channel
	pushstuff $channel
fi
clearcomp
