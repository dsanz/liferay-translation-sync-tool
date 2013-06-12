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
		logt 3 -n "Creating dir $1"
		mkdir -p $1
	else
		logt 3 -n "Using dir $1"
		:
	fi
	check_command
}

####
## Create dir if does not exist, delete its contents otherwise
####
function clean_dir() {
	if [ ! -d $1 ]; then
		logt 3 -n "Creating dir $1"
		mkdir -p $1
	else
		logt 3 -n "Cleaning dir $1"
		rm -Rf $1/*
	fi
	check_command
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
    prefix="";
    [[ $length -gt 0 ]] && prefix="["$(date +%T.%3N)"]"$(printf "%${length}s")
    echo -ne "$LILA"
    baselog "$prefix"
    echo -ne "$color";
    baselog "$@";
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
    3) color=$YELLOW ;;
    4) color=$COLOROFF ;;
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
	echo -e "$LILA[$(date +%T.%3N)]${COLOROFF}$CYAN  Preparing log file $logfile"
	# logbase dir has to be created prior to check_dir call
	mkdir -p $logbase
	check_dir $logbase
}