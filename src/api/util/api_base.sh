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
	dir_name="$1"

	if [[ "$dir_name" == */ ]]; then
		dirname=${dirname%/}
	fi;

	if [ -f $dir_name ]; then
		logt 3 -n "File with same name exists, deleting file $dir_name prior to create a dir"
		rm -f $dir_name
		check_command
	fi;

	if [ ! -d $1 ]; then
		logt 3 -n "Creating dir $dir_name"
		mkdir -p $dir_name
	else
		logt 3 -n "Cleaning dir $dir_name"
		rm -Rf $dir_name/*
	fi

	check_command
}

# given a length for indentation, a color, an optional "-n" and a message, logs coloured
# message to stdout and an uncolored one to the log file.
function loglc() {
	 length=$1
	 shift 1;
	 color=$1;
	 shift 1;
	 character="\n"
	 if [[ "$1" == "-n" ]]; then
		shift 1
		character=""
	 fi;
	 prefix="";
	 [[ $length -gt 0 ]] && prefix="["$(date +%T.%3N)"]"$(printf "%${length}s")
	 printf "$LILA$prefix$color" >> $logfile
	 printf "%s" "$@" >> $logfile
	 printf "$COLOROFF$character" >> $logfile

}


# logs a message using length 0 and the specified color
function logc() {
	loglc 0 "$@"
}

# logs a message using length 0 and no color
function log() {
	loglc 0 "$LIGHT_GRAY" "$@"
}

# logs a message using a number of tabs. The tab number provides a way to compute the color
function logt() {
	depth=$1
	color=$LIGHT_GRAY;
	case "$depth" in
		-1) color=$RED ;;
		0) color=$LIGHT_GRAY ;;
		1) color=$CYAN ;;
		2) color=$WHITE ;;
		3) color=$YELLOW ;;
		4) color=$LIGHT_GRAY ;;
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
	declare -g logbase="$LOG_DIR/$dirname/$subdirname/"
	declare -g logfile="$logbase$filename";
	# this can't be logged because log is not ready yet
	printf "$LILA[$(date +%T.%3N)]${COLOROFF}$CYAN  Preparing log file $logfile\n"
	# logbase dir has to be created prior to check_dir call
	mkdir -p $logbase
	check_dir $logbase

	if [[ "${LR_TRANS_MGR_TAIL_LOG}x" == "1x" ]]; then
		printf "$LILA[$(date +%T.%3N)]${COLOROFF}$CYAN Running tail on logfile\n"
		#if [[ "${LR_TRANS_MGR_COLOR_LOG}x" == "1x" ]]; then
			# even if we have colored logs, standard output will be uncolored
		#	( ( tail -F  $logfile &  echo $! >pid ) | sed -r 's/\x1B\[1;([0-9]+)m//g' & )
			# get the PID of tail not sed!!!
		#	tail_log_pid=$(<pid)
		#else
			tail -F  $logfile &  tail_log_pid=$!
		#fi;
		trap "terminate" EXIT SIGTERM
	fi;
}

function terminate() {
	printf "\n$LILA[$(date +%T.%3N)]${COLOROFF} Killing tail (pid $tail_log_pid)\n"
	kill $tail_log_pid 2>&1 > /dev/null;
	exit 0
}