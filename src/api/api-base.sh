#!/bin/sh

####
## Check last command and echo it's state
####
function check_command() {
	if [ $? -eq 0 ]; then
		logc $GREEN " [OK]"
	else
		logc $RED " [FAIL]"
	fi
}

####
## Create dir if does not exist
####
function check_dir() {
	if [ ! -d $1 ]; then
		logt 1 -n "Creating dir $1"
		mkdir -p $1
	else
		logt 1 -n "Using dir $1"
		:
	fi
	check_command
}

####
## Create dir if does not exist, delete its contents otherwise
####
function clean_dir() {
	if [ ! -d $1 ]; then
		logt 1 -n "Creating dir $1"
		mkdir -p $1
	else
		logt 1 -n "Cleaning dir $1"
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

function baselog() {
    echo -n "$1" | tee -a $logfile
}

function echo_green() { echo -e "$GREEN$@$COLOROFF"; }
function echo_red() { echo -e "$RED$@$COLOROFF"; }
function echo_lila() { echo -e "$LILA$@$COLOROFF"; }
function echo_yellow() { echo -e "$YELLOW$@$COLOROFF"; }
function echo_blue() { echo -e "$BLUE$@$COLOROFF"; }
function echo_white() { echo -e "$WHITE$@$COLOROFF"; }
function echo_cyan() { echo -e "$CYAN$@$COLOROFF"; }

function log_cyan() { echo -ne "$CYAN"; baselog "$@"; echo -ne "$COLOROFF"; }

function loglc() {
    length=$1
    shift 1;
    color=$1;
    shift 1;
    newline=true;
    if [[ "$1" == "-n" ]]; then
        shift 1
        newline=false;
    fi;
    echo -ne "$color";
    prefix="";
    [[ $length -gt 0 ]] && prefix=$(printf "%${length}s")
    baselog "$prefix$@";
    echo -ne "$COLOROFF";
    $newline && echo | tee -a $logfile
}

function logc() {
    loglc 0 "$@"
}

function log() {
    loglc 0 "$COLOROFF" "$@"
}

function logt() {
    depth=$1
    color=$COLOROFF;
    case "$depth" in
    -1) color=$RED ;;
    0) color=$COLOROFF ;;
    1) color=$CYAN ;;
    2) color=$WHITE ;;
    3) color=$GREEN ;;
    esac;
    length=$(( $depth * 2 ))
    shift 1;
    loglc "$length" "$color" "$@"
}


function set_log_dir() {
    dirname=$(date +%Y-%m);
    subdirname=$(date +%F_%H-%M-%S)
	filename="pootle_manager.log";
	logbase="$LOG_DIR/$dirname/$subdirname/"
	logfile="$logbase$filename";
	# this can't be logged because log is not ready yet
	echo -e "${COLOROFF}Logging to $logfile"
	# logbase dir has to be created prior to check_dir call
	mkdir -p $logbase
	check_dir $logbase
}