#!/bin/sh
#
### BEGIN INIT INFO
# Provides:             common-functions
# Required-Start:	$syslog $time
# Required-Stop:	$syslog $time
# Short-Description:	Functions used in scripts
# Description:		Common functions used across management scripts.
# 			There should not be script specific functions.
# Author:		Milan Jaroš, Daniel Sanz, Alberto Montero
# Version: 		1.0
# Dependences:
### END INIT INFO


####
## Check last command and echo it's state
####
function check_command() {
	if [ $? -eq 0 ]; then
		echo_yellow "OK"
	else
		echo_red "FAIL"
	fi
}

####
## Create dir if does not exist
####
function check_dir() {
	if [ ! -d $1 ]; then
		echo -n "    Creating dir $1 "
		mkdir -p $1
	else
		echo -n "    Using dir $1 "
	fi
	check_command
}

####
## Create dir if does not exist, delete its contents otherwise
####
function clean_dir() {
	if [ ! -d $1 ]; then
		echo -n "    Creating dir $1 "
		mkdir -p $1
	else
		echo -n "    Cleaning dir $1 "
		rm -Rf $1/*
	fi
	check_command
}

####
## Report directory - function for development
####
# $1 - project
# $2 - dir
# $3 - file prefix
function report_dir() {
	file "{$2}*" > "/var/tmp/$1/$3.txt"
}

####
## Wait for user "any key" input
####
function any_key() {
	echo -n "Press any key to continue..."
	read -s -n 1
	echo
}

####
## Echo coloured messages
####
# $@ - Message (all parameters)
COLOROFF="\033[1;0m"; GREEN="\033[1;32m"; RED="\033[1;31m"; LILA="\033[1;35m"
YELLOW="\033[1;33m"; BLUE="\033[1;34m"; WHITE="\033[1;37m"; CYAN="\033[1;36m"

function echo_green() { echo -e "$GREEN$@$COLOROFF"; }
function echo_red() { echo -e "$RED$@$COLOROFF"; }
function echo_lila() { echo -e "$LILA$@$COLOROFF"; }
function echo_yellow() { echo -e "$YELLOW$@$COLOROFF"; }
function echo_blue() { echo -e "$BLUE$@$COLOROFF"; }
function echo_white() { echo -e "$WHITE$@$COLOROFF"; }
function echo_cyan() { echo -e "$CYAN$@$COLOROFF"; }

####
## Get parameter
####
# $1 - Which parameter would you like to get
# $2 - Get parameter from this list (usually something like ${PROJECTS[$i]})
function get_param() {
	shift $1
	echo  $1
}

####
## Verify parameters
####
# $1 - How many parameters should be passed on, otherwise fail...
# $2 - Message to be displayed if verification failed
# $* - Parameters to be verified
function verify_params() {
	[ "$#" -lt $(($1 + 2)) ] && echo_red "$2" && exit 1
}

function backup_db() {
	echo_cyan "[`date`] Backing up Pootle DB..."
	dirname=$(date +%Y-%m);
	filename=$(echo $(date +%F_%H-%M-%S)"-pootle.sql");
	dumpfile="$TMP_DB_BACKUP_DIR/$dirname/$filename";

	echo_white "  Dumping Pootle DB into $dumpfile"
	check_dir "$TMP_DB_BACKUP_DIR/$dirname"
	echo -n  "    Running dump command ";
	$DB_DUMP_COMMAND > $dumpfile;
	check_command;
}

# Given a project, returns the root dir where sources are supposed to be
function get_src_working_dir() {
	project="$1"
	if [[ $project == $PORTAL_PROJECT_ID ]]; then
		result=$SRC_PORTAL_BASE;
	else
		result=$SRC_PLUGINS_BASE;
	fi;
	echo $result
}

function exists_branch() {
	branch_name="$1"
	src_dir="$2"
	old_dir=$(pwd)
	cd $src_dir
	rexp="\b$branch_name\b"
	branches="$(git branch | sed 's/\*//g')"
	cd $old_dir
	[[ "$branches" =~ $rexp ]]
}