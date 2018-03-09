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
#
#
## Usage
# copy the user.config.sample file to $tmp_directory/.user.config
# replace mailaddr_to/_from and possibly the tslog path to fit your needs
# place inside /etc/cron.daily to run this script on a daily basis

#### Settings ####

# user specific config file
tmp_directory=/tmp/teamspeak/daily_mail
archive=/var/log/teamspeak
configfile=$tmp_directory/.user.config
configfile_secured=$tmp_directory/tmp.config
backupconf=/var/backups/teamspeak_log_daily_mail_user.config

# system specific variables
tslogs=/etc/teamspeak3-server_linux_amd64/logs
service_script=ts3server.service
tsuser=teamspeak

#### Business logic ####
#### DO NOT ALTER ####

# log files
logfiles=$tmp_directory/teamspeak_daily_log_files.txt
daily_log=$tmp_directory/teamspeak_daily_log.txt

# compositon variables
composition1=$tmp_directory/composition1.txt
composition2=$tmp_directory/composition2.txt
composition3=$tmp_directory/composition3.txt
message_body=$tmp_directory/teamspeak_log_messagebody.txt
mailcomposition=$tmp_directory/teamspeak_mail_composition.txt

# debug parameter
debug=false

#### FUNCTION SECTION ####

# preparations
prerun_check()
{
	# check if all commands needed to run are present in $PATH
	needed_commands="printf rm ls echo grep sort cat date sendmail"
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

	# check if tmp directory is present if not create it
	if [ ! -d "$tmp_directory" ]; then
		mkdir -p "$tmp_directory"
	fi

	# first run check
	# check for presents of the configfile if not exit
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

	clearcomp -all
}

collect_and_prepare()
{
	## log file selection
	# get the currently used logfiles
	ls -t "$tslogs" | head -n2 | sort > "$logfiles"

	# from the $logfiles get everything from today
	grep "$(date -d "$1" '+%Y-%m-%d')" "$tslogs/$(sed -n '1p' $logfiles)" >> $daily_log
	grep "$(date -d "$1" '+%Y-%m-%d')" "$tslogs/$(sed -n '2p' $logfiles)" >> $daily_log
}

#### General Functions ####

clearcomp()
{
	if [ "$1" = "-all" ]; then
		# deleting possible old content
		rm -f "$composition1" "$composition2" "$logfiles" "$daily_log" "$message_body" "$mailcomposition"
	fi
	# remove the composition files
	rm -f "$composition1" "$composition2" "$composition3"
	changed=false
}

#### Mail ####

start_finish()
{
	# function to generate sections header
	if [ "$1" = "--teamspeak-start" ]; then
		echo -e "-------------------- Teamspeak End -----------------------" >> $message_body
	fi
	if [ "$1" = "--teamspeak-end" ]; then
		echo -e "-------------------- Teamspeak End -----------------------" >> $message_body
	fi
}

archive_mail()
{
	# only run this functions if $enable_archive is true
	if [ "$enable_archive" != "false" ]; then
		# check if archive directory is present
		if [ ! -d "$archive" ]; then
			mkdir -p "$tmp_directory"
		fi
		cat "$message_body" >> $archive/teamspeak_report.log
	fi
}

send_mail()
{
	# only send mails if $email = yes
	if [ "$email" = yes ]; then
		# file is not empty
		{	echo -e "To: $mailaddr_to"
		 	echo -e "From: $mailaddr_from"
		 	echo -e "Subject: LogReport Teamspeak $(date -d "yesterday" '+%d.%m.%Y')\\n"
		 	cat "$message_body"
		} >> "$mailcomposition"
		su "$tsuser" -s /bin/sh -c "cat $mailcomposition | /usr/sbin/sendmail -t"
	fi
}

#### FILTER CODE SECTION ####

general_filter()
{
	# general filter which will shift through all positional parameters and filter for that
	while [ "$1" ]
	do
		grep -E "$1" "$daily_log" | sort >> "$composition1"

		# only paste the results if there are any
		if [ -s "$composition1" ]; then
			{	echo -e "------------------- $1 --------------------\\n"
			 	cat "$composition1"
			 	echo -e "----------------- $1 End ------------------\\n"
			} >> "$message_body"
		fi
		clearcomp
		shift
	done
}

filter_server()
{
	# generate report header with info from the systemd script
	{	echo -e "LogReport Teamspeak $(date -d "yesterday" '+%d.%m.%Y')\\n"
		start_finish --teamspeak-start
		# server section
		echo -e "-------------------- Server -----------------------\\n"
		echo -e "Status : $(systemctl status $service_script)\\n"
	} >> "$message_body"

	# only run this filter if $enable_server is true
	if [ "$enable_server" != "false" ]; then
		general_filter "ServerMain|stopped" "ERROR" "WARNING" "Accounting" "CIDRManager"
	fi

	echo -e "------------------ Server End ---------------------\\n" >> "$message_body"
}

filter_group()
{
	# only run this filter if $enable_groups is true
	if [ "$enable_groups" != "false" ]; then
		grep -E "was deleted by|was copied by|was added to|was added by|was removed from" "$daily_log" | grep -v "permission '" >>  "$composition1"

		# only paste the results if there are
		if [ -s "$composition1" ]; then
			echo -e "------------------ Group change -------------------" >> "$message_body"

			# filter for created or copied group events
			grep -E "was copied by|was added by" $composition1 > $composition2
			if [ -s "$composition2" ]; then
				{	echo -e "--- created/ copied ---\\n"
					cat "$composition2"
					changed=true
				} >> "$composition3"
			fi

			# filter for deleted group events
			grep "was deleted by" "$composition1" > "$composition2"
			if [ -s "$composition2" ]; then
				{	echo -e "--- deleted ---\\n"
					cat "$composition2"
					changed=true
				} >> "$composition3"
			fi

			# filter if sombody was added to servergroup
			grep "was added to" "$composition1" > "$composition2"
			if [ -s "$composition2" ]; then
				{	echo -e "--- added to---\\n"
					cat "$composition2"
					changed=true
				} >> "$composition3"
			fi

			# filter if somebody was removed from a group
			grep "was removed from" "$composition1" > "$composition2"
			if [ -s "$composition2" ]; then
				{	echo -e "--- removed from---\\n"
					cat "$composition2"
					changed=true
				} >> "$composition3"
			fi

			# if "changed" is true then paste the results in the mask
			if [ "$changed" = "true" ]; then
				{	echo -e "---- Group ----"
				 	cat "$composition3"
				 	echo -e "\\n---- Group End ----"
				} >> "$message_body"
			fi
			echo -e "---------------- Group change End -----------------\\n" >> "$message_body"
		fi
		clearcomp
	fi
}

filter_channel()
{
	# only run this filter if $enable_channel is true
	if [ "$enable_channel" != "false" ]; then

		# filter for channel creation events
		grep "channel" "$daily_log" | grep "VirtualServerBase">> "$composition1"

		# only paste the results if there are
		if [ -s "$composition1" ]; then
			{	echo -e "--------------------- Channel ---------------------\\n"
			 	cat "$composition1"
			 	echo -e "------------------- Channel End -------------------\\n"
			} >> "$message_body"
		fi
		clearcomp
	fi
}

filter_user_activity()
{
	# only enable this filter if $enable_complaint is true
	if [ "$enable_complaint" != "false" ]; then
		general_filter "^complaint"
	fi

	# only enable this filter if $enable_ban is true
	if [ "$enable_ban" != "false" ]; then
		general_filter "ban added|BanManager"
	fi

	# only enalbe this filter if $enable_kick is true
	if [ "$enable_kick" != "false" ]; then
		general_filter "reason 'invokerid"
	fi

	# only enable this filter if $enable_perm is true
	if [ "$enable_perm" != "false" ]; then
		general_filter   "permission"
	fi
}

#### MAIN CODE SECTION ####

# run all preparations and inital checks
# clear old stuff
clearcomp -all

# prepare folders and config files
prerun_check

# collect and prepare logs and needed files

if [ "$debug" = "true" ]; then
	# forcefully use the logentries from today
	collect_and_prepare today
else
	# the normal routine
	collect_and_prepare yesterday
fi

# if enabled filter server loglines
filter_server

# if enabled filter group changes
filter_group

# if enabled filter channel changesPermission
filter_channel

# if enabled filter user activity (ban / kick / complaint / permission changes)
filter_user_activity

# end mail body
start_finish --teamspeak-end

# if enabled archive mail body
archive_mail

# deliver the generated mail to the configured reciever
send_mail

# cleaning up
clearcomp -all
