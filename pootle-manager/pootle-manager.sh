#!/bin/bash
#
# Author:		Milan Jaros, Daniel Sanz, Alberto Montero
# Version: 		2.0

function load_api() {
	# Load base APIs
	. api-base.sh
	. api-config.sh
	. api-git.sh
	. api-http.sh
	. api-db.sh

	# Load APIs
	. to_pootle.sh
	. to-pootle_file_poster.sh
	. from_pootle.sh
}

####
## Top-level functions
####
	# updates git branch, then updates pootle translations of each project so that:
	#  . only keys contained in Language.properties are processed
	#  . new/deleted keys in Language.properties are conveniently updated in pootle project
	# preconditions:
	#  . project must exist in pootle
	#  . portal/plugin sources are available and are under git control
function src2pootle() {
	backup_db
	prepare_input_dirs
	setup_working_branches
	update_pootle_db
	post_language_translations # bug #1949
	rotate_working_branches
}

function pootle2src() {
	prepare_output_dirs
	update_pootle_files
	ascii_2_native
	process_untranslated
	prepare_vcs
}

main() {
	load_api
	load_config
	resolve_params $@
	# Simple configuration test
	#verify_params 19 "Configuration load failed. You should fill in all variables in pootle-manager.conf." \
		#$POOTLEDIR $PODIR $TMP_DIR $TMP_PROP_IN_DIR $TMP_PROP_OUT_DIR $TMP_PO_DIR \
		#$PO_USER $PO_PASS $PO_HOST $PO_PORT $PO_SRV \
		#$PO_COOKIES $SRC_PATH_PLUGIN_PREFIX \
		#$SRC_PATH_PLUGIN_SUFFIX $FILE $PROP_EXT $PO_EXT $POT_EXT $LANG_SEP
	if [ $UPDATE_REPOSITORY ]; then
		pootle2src
	fi
	if [ $UPDATE_POOTLE_DB ]; then
		src2pootle
	fi
	[ ! $HELP ] &&	echo_green "[`date`] Pootle manager [DONE]"
}

main $@