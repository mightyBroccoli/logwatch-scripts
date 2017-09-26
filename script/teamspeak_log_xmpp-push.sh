#!/bin/bash
#
## Version 1.2.5
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
tmp_directory=/tmp/teamspeak/xmpp_push
tslogs=/etc/teamspeak3-server_linux_amd64/logs
configfile=$tmp_directory/.user.config
configfile_secured=$tmp_directory/.tmp.config
backupconf=/var/backups/teamspeak_log_xmpp-push_user.config

#### DONT CHANGE FROM HERE ####
# compositon variables
composition1=$tmp_directory/composition1.txt
composition2=$tmp_directory/composition2.txt
composition3=$tmp_directory/composition3.txt
final_composition=$tmp_directory/final_composition.txt

server=$tmp_directory/server.txt
complaint=$tmp_directory/complaint.txt
ban=$tmp_directory/ban.txt
kick=$tmp_directory/kick.txt
groupchange=$tmp_directory/groupchange.txt
channel=$tmp_directory/channel.txt

# selection variables
logfiles=$tmp_directory/logfiles.txt
log_selection_today_unsorted=$tmp_directory/selection_today_unsorted.txt
log_selection_today=$tmp_directory/selection_today_sorted.txt
log_removed_old=$tmp_directory/selection_removed_old.txt
log_history=$tmp_directory/today_history.txt
currentday=$(date -u '+%Y-%m-%d')

# debug parameter
debug=false

###### PRE RUN FUNCTION SECTION ######
prerun_check()
{
	needed_commands="rm ls echo grep sort cat date sendxmpp"
	missing_counter=0
	for needed_command in $needed_commands; do
		if ! hash "$needed_command" >/dev/null 2>&1 ; then
			printf "Command not found in PATH: %s\\n" "$needed_command" >&2
			((missing_counter++))
		fi
	done

	if ((missing_counter > 0)); then
		printf "Minimum %d commands are missing in PATH, aborting\\n" "$missing_counter" >&2
		exit 11
	fi

	#check if tmp directory is present if not create it
	if [ ! -d "$tmp_directory" ]; then
		mkdir -p $tmp_directory
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

###### General Functions ######
clearcomp()
{
	if [ "$1" = "-all" ]; then
		#deleting possible old content
		rm -f "$logfiles" "$selection_today_unsorted" "$selection_today_sorted" "$selection_removed_old" "$server" "$complaint" "$ban" "$kick" "$groupchange" "$channel" "$final_composition"
	fi
	# remove the composition files
	rm -f "$composition1" "$composition2" "$composition3"
	changed=false
}

debug()
{
	# debug parameter
	if [ "$debug" = "true" ]; then
		#forcefully delete history every time the script runs
		rm $log_history
	fi
}

display_help()
{
	echo -e "Teamspeak Log XMPP Push script"
	echo -e "Run this script via Cronjob or periodically to achive full functionallity."
	echo -e "Possible paramters"
	echo -e "-h | -help : Print this message"
	echo -e "\\nError Codes"
	echo -e "10 : no config file is found, please use the install steps on Bitbucket."
	echo -e "11 : missing dependencies"
}

# catch  -h / --help
if [ "$1" = "-h" -o "$1" = "--help" ]; then
	display_help
fi

pushstuff()
{
	# remove empty lines and push the result
	grep -v "^$" $final_composition | sendxmpp -u "$xmpp_username" -p "$xmpp_password" -j "$xmpp_server" --tls --resource "$ressource" "$xmpp_recipient"

	# purge tmp files after push
	clearcomp -all
}

###### FILTER CODE SECTION ######
# Filter Server Messages Accounting/ ServerMain / Warning / ERROR / CIDRManager
filter_server()
{
	# only run this filter if $enable_server is true
	if [ "$enable_server" != false ]; then
		grep -E 'ServerMain|stopped|Accounting|Warning|ERROR|CIDRManager' $log_removed_old  >> $composition1

		# only paste the results if there are
		if [ -s $composition1 ]; then
			{	echo -e "\\n---- Server ----\\n"
				cat $composition1
				echo -e "\\n---- Server End ----"
			} >> $server
			cat $server >> $final_composition
		fi
		clearcomp
	fi
}

# Filter complaints
filter_complaint()
{
	# only run this filter if $enable_complaint is true
	if [ "$enable_complaint" != false ]; then
		grep "^complaint" $log_removed_old >> $composition1

		# only paste the results if there are
		if [ -s $composition1 ]; then
			{	echo -e "\\n---- Complaint ----\\n"
				cat $composition1
				echo -e "\\n---- Complaint End ----"
			} >> $complaint
			cat $complaint >> $final_composition
		fi
		clearcomp
	fi
}

# Filter Kick messages
filter_kick()
{
	# only run this filter if $enable_kick is true
	if [ "$enable_kick" != false ]; then
		grep "reason 'invokerid" $log_removed_old | grep -v "bantime" >> $composition1

		# only paste the results if there are
		if [ -s $composition1 ]; then
			{	echo -e "\\n---- Kick ----\\n"
				cat $composition1
				echo -e "\\n---- Kick End ----"
			} >> $kick
			cat $kick >> $final_composition
		fi
		clearcomp
	fi
}

# Filter Channels added /deleted / edited
filter_channel()
{
	# only run this filter if $enable_channel is true
	if [ "$enable_channel" != false ];then
		grep "channel" $log_removed_old | grep VirtualServerBase > $composition1

		# only paste the results if there are
		if [ -s $composition1 ]; then
			{	echo -e "\\n---- Channel ----\\n"
				cat $composition1
				echo -e "\\n---- Channel End ----"
			} >> $channel
			cat $channel >> $final_composition
		fi
		clearcomp
	fi
}

# Filter bans added / deleted and general BanManager messages
filter_ban()
{
	# only run this filter if $enable_ban is true
	if [ "$enable_ban" != false ]; then
		# first collect all ban related events
		grep -E 'ban added|BanManager|ban deleted' $log_removed_old  >> $composition1

		# only paste the results if there are
		if [ -s $composition1 ]; then
			# filter added bans
			grep -E 'ban added' $composition1 > $composition2
			if [ -s $composition2 ]; then
				{	echo -e "--- Ban added ---\\n"
					cat $composition2
					# change the "changed" value to true to indicate something has changed
					changed=true
				} >> $composition3
			fi

			# filter deleted bans
			grep -E 'BanManager|ban deleted' $composition1 > $composition2
			if [ -s $composition2 ]; then
				{	echo -e "--- Ban deleted ---\\n"
					cat $composition2
					# change the "changed" value to true to indicate something has changed
					changed=true
				} >> $composition3
			fi
		fi

		# if "changed" is true paste the results in this mask
		if [ "$changed" = true ]; then
			{	echo -e "\\n---- Ban ----"
				cat $composition3
				echo -e "\\n---- Ban End ----"
			}>> $ban
			cat $ban >> $final_composition
		fi
		clearcomp
	fi
}

# Filter Group changes
filter_groups()
{
	# only enable this filter if $enable_groups is true
	if [ "$enable_groups" != false ]; then
		grep -E "was deleted by|was copied by|was added to|was added by|was removed from" $log_removed_old | grep -v "permission '" > $composition1

		# only paste the results if there are
		if [ -s $composition1 ]; then
			#filter created or copied group events
			grep -E "was copied by|was added by" $composition1 > $composition2
			if [ -s $composition2 ]; then
				{	echo -e "--- created/ copied ---\\n"
					cat $composition2
					changed=true
				} >> $composition3
			fi

			# filter deleted group events
			grep "was deleted by" $composition1 > $composition2
			if [ -s $composition2 ]; then
				{	echo -e "--- deleted ---\\n"
					cat $composition2
					changed=true
				} >> $composition3
			fi

			# filter somebodys group changed
			grep "was added to" $composition1 > $composition2
			if [ -s $composition2 ]; then
				{	echo -e "--- added to---\\n"
					cat $composition2
					changed=true
				} >> $composition3
			fi

			# filter somebody got removed from a group
			grep "was removed from" $composition1 > $composition2
			if [ -s $composition2 ]; then
				{	echo -e "--- removed from---\\n"
					cat $composition2
					changed=true
				} >> $composition3
			fi
		fi

		# if "changed" = true paste all results in this mask
		if [ "$changed" = true ]; then
			{	echo -e "\\n---- Group ----"
			 	cat $composition3
			 	echo -e "\\n---- Group End ----"
			} >> $groupchange
			cat $groupchange >> $final_composition
		fi
		clearcomp
	fi
}

###### MAIN CODE SECTION ######
#run all preparations and inital checks
# clear old stuff
clearcomp -all
# prepare folders and config files
prerun_check
# collect and prepare logs and needed files
collect_and_prepare
#debug parameters
debug

## server
filter_server

## Complaint
filter_complaint

## Ban
filter_ban

## Kick
filter_kick

## Group change
filter_groups

## Channel
filter_channel

## Push Message
pushstuff
