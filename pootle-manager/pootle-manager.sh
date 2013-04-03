#!/bin/bash
#
### BEGIN INIT INFO
# Provides:             pootle
# Required-Start:	$syslog $time
# Required-Stop:	$syslog $time
# Short-Description:	Manage pootle easily. 
# Description:		Provides some automatization processes and simplify
# 			management of Pootle.
# Author:		Milan Jaros, Daniel Sanz, Alberto Montero                               
# Version: 		2.0
# Dependences:		svn, native2ascii, pootle-2.1.2
### END INIT INFO

# Load configuration
. pootle-manager.conf

# Load common functions
. common-functions.sh
. to_pootle.sh
. from_pootle.sh

# Simple configuration test
verify_params 25 "Configuration load failed. You should fill in all variables in pootle-manager.conf." \
	$POOTLEDIR $PODIR $TMP_DIR $TMP_PROP_IN_DIR $TMP_PROP_OUT_DIR $TMP_PO_DIR \
	$PO_USER $PO_PASS $PO_HOST $PO_PORT $PO_SRV \
	$PO_COOKIES $SVN_HOST $SVN_PORT $SVN_PATH $SVN_PATH_PLUGIN_PREFIX \
	$SVN_PATH_PLUGIN_SUFFIX $FILE $PROP_EXT $PO_EXT $POT_EXT $LANG_SEP

####
## Resolve parameters
####
# $1 - This parameter must contain $@ (parameters to resolve).
function resolve_params() {
	params="$@"
	[ "$params" = "" ] && export HELP=1
	for param in $params ; do
		if [ "$param" = "--pootle2repo" ] || [ "$param" = "-r" ]; then
			export UPDATE_REPOSITORY=1
		elif [ "$param" = "--repo2pootle" ] || [ "$param" = "-p" ]; then
			export UPDATE_POOTLE_DB=1
		elif [ "$param" = "--help" ] && [ "$param" = "-h" ] && [ "$param" = "/?" ]; then
			export HELP=1
		else
			echo_red "PAY ATTENTION! You've used unknown parameter."
			any_key
		fi
	done
	if [ $HELP ]; then
		echo_white ".: Pootle Manager 1.9 :."
		echo
		echo "This is simple Pootle management tool that syncrhonizes the translations from VCS repository to pootle DB and vice-versa, taking into account automatic translations (which are uploaded as suggestions to pootle). Please, you should have configured variables in the script."
		echo "Arguments:"
		echo "  -r, --pootle2repo	Sync. stores of pootle and prepares files for commit to VCS (does not commit any file)"
		echo "  -p, --repo2pootle	Updates all language files from VCS repository and update Pootle database."
		echo

		UPDATE_REPOSITORY=
		UPDATE_POOTLE_DB=
	else
		echo_green "[`date`] Pootle manager [START]"
	fi
}

####
## Top-level functions
####

	# checks out projects from SVN, updating pootle translations of each project so that:
	#  . only keys contained in Language.properties are processed
	#  . new/deleted keys in Language.properties are conveniently updated in pootle project
	# preconditions:
	#  . project must exist in pootle
function svn2pootle() {
	backup_db
	prepare_input_dirs
	update_pootle_db
}

function pootle2svn() {
	prepare_output_dirs
	update_pootle_files
	keep_template
	reformat_pootle_files
	ascii_2_native
	add_untranslated
	prepare_vcs
}

####
## Update 
####
function update() {
	# There should be placed UNDER MAINTANANCE mechanism
	if [ $UPDATE_REPOSITORY ]; then
		pootle2svn
	fi
	if [ $UPDATE_POOTLE_DB ]; then
		svn2pootle
	fi
	[ ! $HELP ] &&	echo_green "[`date`] Pootle manager [DONE]"
}

main() {
	resolve_params $@
	update
}

main $@
