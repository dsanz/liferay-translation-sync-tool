#!/bin/sh

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

