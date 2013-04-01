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

# TODO:
#	auto-run this script (cron - once per week?): pootle-manager.sh --update-repository --update-pootle-db
#	UNDER MAINTANANCE information into Apache Pootle root (line 281) 

# Load configuration
. pootle-manager.conf
# Load common functions
. common-functions.sh
. vcs-svn.sh
. file-conversions.sh
. pootle_input.sh
. pootle_output.sh

# Simple configuration test
verify_params 25 "Configuration load failed. You should fill in all variables in pootle-manager.conf." \
	$POOTLEDIR $PODIR $TMP_DIR $TMP_PROP_IN_DIR $TMP_PROP_OUT_DIR $TMP_PO_DIR \
	$SVNDIR $SVN_USER $SVN_PASS $PO_USER $PO_PASS $PO_HOST $PO_PORT $PO_SRV \
	$PO_COOKIES $SVN_HOST $SVN_PORT $SVN_PATH $SVN_SRV $SVN_PATH_PLUGIN_PREFIX \
	$SVN_PATH_PLUGIN_SUFFIX $FILE $PROP_EXT $PO_EXT $POT_EXT $LANG_SEP

####
## Resolve parameters
####
# $1 - This parameter must contain $@ (parameters to resolve).
    resolve_params() {
    	params="$@"
    	[ "$params" = "" ] && export HELP=1
	for param in $params ; do
		if [ "$param" = "--pootle2repo" ] || [ "$param" = "-r" ]; then
			export UPDATE_REPOSITORY=1
		elif [ "$param" = "--repo2pootle" ] || [ "$param" = "-p" ]; then
			export UPDATE_POOTLE_DB=1
		elif [ "$param" = "--disable-new" ] || [ "$param" = "-d" ]; then
			export DISABLE_NEW=1
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
		echo "  -d, --disable-new	(only in conjunction with -p) Disables detection of new languages added to projects on the file system." 
		echo 

		UPDATE_REPOSITORY=
		UPDATE_POOTLE_DB=
		DISABLE_NEW=
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
    svn2pootle() {
    # back-up database before importing anything
    backup_db
    # prepare working dirs
    prepare_input_dirs
	#checkout .properties files from SVN
	checkout_projects
	# let Pootle read the translation files
	update_pootle_db
    }

    pootle2svn() {
	# prepare working dirs
    prepare_output_dirs
	# let Pootle write its DB contents to translation files
	update_pootle_files
	# generate and keep a .po file for later export format conversion
	keep_template
	# make sure comments and blank lines remain in place
	reformat_pootle_files
	# convert them back to native format (this must be done before further manipulations)
	ascii_2_native
	# any untranslated key exported by pootle is substituted by its automatic translation/copy
	add_untranslated
	# copy files to VCS working copy
	prepare_vcs
	# TODO: do commit or notify someone to do that

    }

####
## Update 
####
    update() {
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
