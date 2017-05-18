#!/bin/bash
#
## Version 1.2.0
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
# copy the user.config.sample file to $tmp_directory/.user.config
# edit all the user variables and possibly the tslog path to fit your needs
# run this script every x minutes to send the lines accumulated in the log files via cron eg
# */x * * * * /PATH/teamspeak_log_xmpp-push.sh

#variables
tmp_directory=/tmp/teamspeak
tslogs=/etc/teamspeak3-server_linux_amd64/logs
configfile=$tmp_directory/.user.config
configfile_secured=$tmp_directory/.tmp.config
backupconf=/var/backups/teamspeak_log_xmpp-push_user.config

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
	sendxmpp -u "$xmpp_username" -p "$xmpp_password" -j "$xmpp_server" --tls --resource "$ressource" "$xmpp_recipient" --message "$1"
}

clearcomp()
{
	# remove the composition files
	rm $composition1 $composition2 $composition3 >/dev/null 2>&1
}


## preparations
#check if tmp directory is present if not create it
if [ ! -d "$tmp_directory" ]; then
	mkdir $tmp_directory
fi

#first run check
if [ ! -f "$configfile" ]; then
	if [ -f "$backupconf" ]; then
		echo -e "no config inside $tmp_directory using $backupconf"
		cp "$backupconf" "$configfile"
	else
		#config file is not present
		echo -e "no config file has been set. copy the sample config file to $configfile"
		exit
	fi
else
	# copy config file to /var/backup
	cp "$configfile" "$backupconf"
fi

# check if config file contains something we don't want
if	grep -E -q -v '^#|^[^ ]*=[^;]*' "$configfile"; then
	grep -E '^#|^[^ ]*=[^;&]*'  "$configfile" > "$configfile_secured"
	configfile="$configfile_secured"
fi

# source the config file
source  "$configfile"

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

{	echo -e "\n---- Server ----\n"
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

{	echo -e "\n---- Complaint ----\n"
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
{	echo -e "\n---- Ban ----\n"
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

{	echo -e "\n---- Kick ----\n"
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
grep -E "was deleted by|was copied by|was added to|was added by|was removed from" $log_removed_old | grep -v "permission '" > $composition1

#created or copied group
grep -E "was copied by|was added by" $composition1 > $composition3
if [ -s $composition3 ]; then
	{
		echo -e "--- created/ copied ---\n"
		cat $composition3
	} >> $composition2
fi

# deleted group
grep "was deleted by" $composition1 > $composition3
if [ -s $composition3 ]; then
	{
		echo -e "--- deleted ---\n"
		cat $composition3
	} >> $composition2
fi

# sombody was added to servergroup
grep "was added to" $composition1 > $composition3
if [ -s $composition3 ]; then
	{
		echo -e "--- added to---\n"
		cat $composition3
	} >> $composition2
fi

#somebody was removed from a group
grep "was removed from" $composition1 > $composition3
if [ -s $composition3 ]; then
	{
		echo -e "--- removed from---\n"
		cat $composition3
	} >> $composition2
fi

#paste the shit into the file
if [ -s $composition2 ]; then
	{	echo -e "\n---- Group ----"
	 	cat $composition2
	 	echo -e "---- Group End ----"
	} >> $groupchange
	pushstuff $groupchange
fi
clearcomp

## Channel ##
grep channel $log_removed_old | grep VirtualServerBase > $composition1
{	echo -e "\n---- Channel ----\n"
	sort $composition1
	echo -e "---- Channel End ----"
} > $composition2

#paste the shit into the file and remove the tmp files afterwords
if [ -s $composition1 ]; then
	cat $composition2 > $channel
	pushstuff $channel
fi
clearcomp
