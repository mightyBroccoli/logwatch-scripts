filter#!/bin/bash
#
## Version 1.2.4
#
#
## Dependencies
#
# shell access
# teamspeak 3 server
# anacron / cron
# bash > 4.2
# bashutils
# sendxmpp
# perl
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

# default parameters
diagnostic=no

###### FUNCTION SECTION ######
display_help()
{
	echo -e "Teamspeak Log XMPP Push script"
	echo -e "Run this script via Cronjob or periodically to achive full functionallity."
	echo -e "Possible paramters"
	echo -e "-h | -help : Print this message"
	echo -e "-diagnostic | -diag LOGFILE : diagnostics on the given Teamspeak Logfile."
	echo -e "\nError Codes"
	echo -e "10 : no config file is found, please use the install steps on Bitbucket."
	echo -e "11 : missing dependencies"
	echo -e "12 : missing logfile for diagnostic function"
}
pushstuff()
{
	# xmpp push function with variable message
	sendxmpp -u "$xmpp_username" -p "$xmpp_password" -j "$xmpp_server" --tls --resource "$ressource" "$xmpp_recipient" --message "$1"
}

clearcomp()
{
	if [ "$1" = "-all" ]; then
		#deleting possible old content
		rm -f "$logfiles" "$selection_today_unsorted" "$selection_today_sorted" "$selection_removed_old" "$server" "$complaint" "$ban" "$kick" "$groupchange" "$channel"
	fi
	# remove the composition files
	rm -f "$composition1" "$composition2" "$composition3"
	changed=no
}

prerun_check()
{
	needed_commands="rm ls echo grep sort cat date sendxmpp"
	missing_counter=0
	for needed_command in $needed_commands; do
	  if ! hash "$needed_command" >/dev/null 2>&1 ; then
	    printf "Command not found in PATH: %s\n" "$needed_command" >&2
	    ((missing_counter++))
	  fi
	done

	if ((missing_counter > 0)); then
	  printf "Minimum %d commands are missing in PATH, aborting\n" "$missing_counter" >&2
	  exit 11
	fi

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
			exit 10
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

	#is the history relevant?
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
	clearcomp -all
}

collect_and_prepare()
{
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
}

parameters()
{
	# check all positional parameters if something is matching up
	while : do
		case "$1" in
			# check for positional parameters
			-diag | -diagnostic)
					file="$2"
					if [ -z "$2"]; then
						# no file is give to the diagnostic function
						echo -e "Error no file to diagnose."
						echo -e "Please view the help text for further information."
						exit 12
					fi
					diagnostic=yes
					;;
			-h | -help)
					#displaying the help text
					display_help
					exit 0
					;;
			*)
					#no valid parameters
					break
					echo 1
		esac
	done
}

###### FILTER CODE SECTION ######
# Filter Server Messages Accounting/ ServerMain / Warning / ERROR
filter_server()
{
	grep -E 'ServerMain|stopped|Accounting|Warning|ERROR|CIDRManager' $log_removed_old  >> $composition1
	#if there is something do if not skip
	if [ -s $composition1 ]; then
		{	echo -e "---- Server ----\n"
			cat $composition1
			echo -e "\n---- Server End ----"
		} >> $server
		pushstuff $server
	fi
	clearcomp
}

# Filter complaints
filter_complaint()
{
	grep "^complaint" $log_removed_old >> $composition1
	#if there is something do if not skip
	if [ -s $composition1 ]; then
		{	echo -e "---- Complaint ----\n"
			cat $composition1
			echo -e "\n---- Complaint End ----"
		} >> $complaint
		pushstuff $complaint
	fi
	clearcomp
}

# Filter bans added / deleted and general BanManager messages
filter_ban()
{
	grep -E 'ban added|BanManager|ban deleted' $log_removed_old  >> $composition1
	#if there is something do if not skip
	if [ -s $composition1 ]; then
		#ban added
		grep -E 'ban added' $composition1 > $composition2
		if [ -s $composition2 ]; then
			{	echo -e "--- Ban added ---\n"
				cat $composition2
				changed=yes
			} >> $composition3
		fi

		#ban deleted
		grep -E 'BanManager|ban deleted' $composition1 > $composition2
		if [ -s $composition2 ]; then
			{	echo -e "--- Ban deleted ---\n"
				cat $composition2
				changed=yes
			} >> $composition3
		fi
	fi

	#collect all BanManager info
	if [ "$changed" = yes ]; then
		{	echo -e "---- Ban ----"
			cat $composition3
			echo -e "\n---- Ban End ----"
		}>> $ban
		pushstuff $ban
	fi
	clearcomp
}

# Filter Kick messages
filter_kick()
{
	grep "reason 'invokerid" $log_removed_old | grep -v "bantime" >> $composition1
	#if there is something do if not skip
	if [ -s $composition1 ]; then
		{	echo -e "---- Kick ----\n"
			cat $composition1
			echo -e "\n---- Kick End ----"
		} >> $kick
		pushstuff $kick
	fi
	clearcomp
}

# Filter Group changes
filter_groups()
{
	grep -E "was deleted by|was copied by|was added to|was added by|was removed from" $log_removed_old | grep -v "permission '" > $composition1
	#if there is something do if not skip
	if [ -s $composition1 ]; then
		#created or copied group
		grep -E "was copied by|was added by" $composition1 > $composition2
		if [ -s $composition2 ]; then
			{	echo -e "--- created/ copied ---\n"
				cat $composition2
				changed=yes
			} >> $composition3
		fi

		# deleted group
		grep "was deleted by" $composition1 > $composition2
		if [ -s $composition2 ]; then
			{	echo -e "--- deleted ---\n"
				cat $composition2
				changed=yes
			} >> $composition3
		fi

		# sombody was added to servergroup
		grep "was added to" $composition1 > $composition2
		if [ -s $composition2 ]; then
			{	echo -e "--- added to---\n"
				cat $composition2
				changed=yes
			} >> $composition3
		fi

		#somebody was removed from a group
		grep "was removed from" $composition1 > $composition2
		if [ -s $composition2 ]; then
			{	echo -e "--- removed from---\n"
				cat $composition2
				changed=yes
			} >> $composition3
		fi
	fi

	#collect all groupchange infos
	if [ "$changed" = yes ]; then
		{	echo -e "---- Group ----"
		 	cat $composition3
		 	echo -e "\n---- Group End ----"
		} >> $groupchange
		pushstuff $groupchange
	fi
	clearcomp
}

# Filter Channels added /deleted / edited
filter_channel()
{
	grep channel $log_removed_old | grep VirtualServerBase > $composition1
	#if there is something do if not skip
	if [ -s $composition1 ]; then
		{	echo -e "---- Channel ----\n"
			sort $composition1
			echo -e "\n---- Channel End ----"
		} > $channel
		pushstuff $channel
	fi
	clearcomp
}
###### MAIN CODE SECTION ######

#run all preparations and inital checks
# clear old stuff
clearcomp -all
# prepare folders and config files
prerun_check
# collect and prepare logs and needed files
collect_and_prepare
# check for optional parameters
parameters


## server ##
if [ "$enable_server" != false ]; then
	filter_server
fi

## Complaint ##
if [ "$enable_complaint" != false ]; then
	filter_complaint
fi

## Ban ##
if [ "$enable_ban" != false ]; then
	filter_ban
fi

## Kick ##
if [ "$enable_kick" != false ]; then
	filter_kick
fi

## Group change ##
if [ "$enable_groups" != false ]; then
	filter_groups
fi

## Channel ##
if [ "$enable_channel" != false ];then
	filter_channel
fi

#successfull exit
exit 0
