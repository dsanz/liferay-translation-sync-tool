#!/bin/bash

# Author:		Milan Jaros, Daniel Sanz, Alberto Montero

function load_api() {
	# Load base APIs
	. api/api-base.sh
	. api/api-config.sh
	. api/api-git.sh
	. api/api-http.sh
	. api/api-db.sh
	. api/api-properties.sh

	# Load APIs
	. pootle-api/to_pootle.sh
	. pootle-api/to_pootle-file_poster.sh
	. pootle-api/to_liferay.sh
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
	display_projects
	backup_db
	prepare_input_dirs
	setup_working_branches
	update_pootle_db
	post_language_translations # bug #1949
	rotate_working_branches
}

function pootle2src() {
    display_projects
	prepare_output_dirs
    update_pootle_files
	ascii_2_native
	process_untranslated
	prepare_vcs
}

function display_projects() {
    logt 1 "Working project list"
    for (( i=0; i<${#PROJECT_NAMES[@]}; i++ ));  do
		project=${PROJECT_NAMES[$i]}
		project=$(printf "%-35s%s" "$project")
		logt 2 -n "$project"
		log "$(get_project_language_path $project)"
	done
}

main() {
	echo "$product [START]"
	load_api
	load_config
	resolve_params $@
	# Simple configuration test
	#verify_params 19 "Configuration load failed. You should fill in all variables in pootle-manager.conf.sh." \
		#$POOTLEDIR $PODIR $TMP_DIR $TMP_PROP_IN_DIR $TMP_PROP_OUT_DIR \
		#$PO_USER $PO_PASS $PO_HOST $PO_PORT $PO_SRV \
		#$PO_COOKIES $SRC_PATH_PLUGIN_PREFIX \
		#$SRC_PATH_PLUGIN_SUFFIX $FILE $PROP_EXT $LANG_SEP
	if [ $UPDATE_REPOSITORY ]; then
		pootle2src
	fi
	if [ $UPDATE_POOTLE_DB ]; then
		src2pootle
	fi
	if [ $RESCAN_FILES ]; then
	    uniformize_pootle_paths
	fi
	[ ! $HELP ] &&	echo "$product [DONE]"
}

main $@
