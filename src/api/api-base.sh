#!/bin/sh

# Checks last command and echoes it's state
function check_command() {
	if [ $? -eq 0 ]; then
		logc $GREEN " [OK]"
	else
		logc $RED " [FAIL]"
	fi
}

# Creates dir if does not exist
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

# Creates dir if does not exist, deletes its contents otherwise
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

# some colours
COLOROFF="\033[1;0m"; GREEN="\033[1;32m"; RED="\033[1;31m"; LILA="\033[1;35m"
YELLOW="\033[1;33m"; BLUE="\033[1;34m"; WHITE="\033[1;37m"; CYAN="\033[1;36m"

function baselog() {
	printf "$1" >> $logfile
}

# given a length for indentation, a color, an optional "-n" and a message, logs coloured
# message to stdout and an uncolored one to the log file.
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

	character=""
	$newline && character="\n"
	baselog "$LILA$prefix$color$@$COLOROFF$character";
}

# logs a message using length 0 and the specified color
function logc() {
	loglc 0 "$@"
}

# logs a message using length 0 and no color
function log() {
	loglc 0 "$COLOROFF" "$@"
}

# logs a message using a number of tabs. The tab number provides a way to compute the color
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

# sets the log directory and file for the rest of program functions
function set_log_dir() {
	dirname=$(date +%Y-%m);
	subdirname=$(date +%F_%H-%M-%S)
	filename="pootle_manager.log";
	logbase="$LOG_DIR/$dirname/$subdirname/"
	logfile="$logbase$filename";
	# this can't be logged because log is not ready yet
	printf "$LILA[$(date +%T.%3N)]${COLOROFF}$CYAN  Preparing log file $logfile\n"
	# logbase dir has to be created prior to check_dir call
	mkdir -p $logbase
	check_dir $logbase

	if [[ $LR_TRANS_MGR_TAIL_LOG == "1" ]]; then
		tail -F  $logfile &  tail_log_pid=$!
		trap "terminate" EXIT SIGTERM
	fi;
}

function terminate() {
	printf "\n$LILA[$(date +%T.%3N)]${COLOROFF} Killing tail (pid $tail_log_pid)\n"
	kill $tail_log_pid 2>&1 > /dev/null;
	exit 0
}