#!/bin/bash

# Author:		Milan Jaros, Daniel Sanz, Alberto Montero

# single point for loading all functions defined in the (low-level) api files as well as user-level APIs
function load_api() {
	# Load base APIs
	. api/api-base.sh
	. api/api-config.sh
	. api/api-git.sh
	. api/api-http.sh
	. api/api-db.sh
	. api/api-properties.sh
	. api/api-version.sh
	. api/api-pootle.sh
	. backporter-api/api-files.sh
	. backporter-api/api-git.sh
	. backporter-api/api-properties.sh

	# Load APIs
	. pootle-api/to_pootle.sh
	. pootle-api/to_pootle-file_poster.sh
	. pootle-api/to_liferay.sh
	. pootle-api/provisioning-api.sh
	. backporter-api/api-backporter.sh

    declare -xgr HOME_DIR="$(dirname $(readlink -f $BASH_SOURCE))"
}

####
## Top-level functions
####

# src2pootle implements the sync bewteen liferay source code and pootle storage
# - backups everything
# - pulls from upstream the master branch
# - updates pootle from the template of each project (Language.properties) so that:
#   . only keys contained in Language.properties are processed
#   . new/deleted keys in Language.properties are conveniently updated in pootle project
# - updates any translation committed to liferay source code since last src2pootle sync (pootle built-in
#     'update-translation-projects' can't be used due to a pootle bug, we do this with curl
# - rotates working branches to remember head of last sync

# preconditions:
#  . project must exist in pootle, same 'project code' than git source dir (for plugins)
#  . portal/plugin sources are available and are under git control
function src2pootle() {
    loglc 1 $RED "Begin Sync[Liferay source code -> Pootle]"
	display_projects
	backup_db
	prepare_input_dirs
	setup_working_branches
	update_pootle_db
	post_language_translations # bug #1949
	rotate_working_branches
	loglc 1 $RED "End Sync[Liferay source code -> Pootle]"
}

# pootle2src implements the sync between pootle and liferay source code repos
# - tells pootle to update its files with the DB contents
# - copy and convert those files to utf-8
# - pulls from upstream the master branch
# - process translations by comparing pootle export with contents in master, using a set of predefined rules
# - makes a first commit of this
# - runs ant build-lang for every project
# - commits and pushes the result
# all the process is logged
function pootle2src() {
    loglc 1 $RED "Begin Sync[Pootle -> Liferay source code]"
    display_projects
    prepare_source_dirs
	prepare_output_dirs
    update_pootle_files
	ascii_2_native
	process_untranslated
	do_commit false false "pootle exported keys"
	ant_build_lang
	do_commit true true "ant build-lang"
	loglc 1 $RED "End Sync[Pootle -> Liferay source code]"
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

function backport_all() {
    loglc 1 $RED "Begin backport process"
    display_projects

    use_git=0
    do_commit=0

    # prepare git for all base-paths
    logt 1 "Preparing involved directories"
	for (( i=0; i<${#PATH_BASE_DIR[@]}; i++ ));
	do
		base_src_dir=${PATH_BASE_DIR[$i]}
		check_git "$base_src_dir" "$(get_ee_target_dir $base_src_dir)";
    done

    # backport is done on a project basis
    logt 1 "Backporting"
    for (( i=0; i<${#PROJECT_NAMES[@]}; i++ ));  do
		project=${PROJECT_NAMES[$i]}
		logt 2 "$project"
		source_dir="$(get_project_language_path $project)"
		target_dir=$(get_ee_target_dir $source_dir)
		backport_project "$source_dir" "$target_dir"
	done;

    # commit result is again done on a base-path basis
    logt 1 "Committing backport process results"
	for (( i=0; i<${#PATH_BASE_DIR[@]}; i++ ));
	do
		base_src_dir=${PATH_BASE_DIR[$i]}
		commit_result  "$base_src_dir" "$(get_ee_target_dir $base_src_dir)"
    done

    loglc 1 $RED "End backport process"
}

function upload_translations() {
    loglc 1 $RED  "Uploading $2 translations for project $1"
    post_file $1 $2
    loglc 1 $RED "Upload finished"
}

function add_project_in_pootle() {
    projectCode="$1"
    projectName="$2"
     logt 1 "HEY"
    if is_pootle_server_up; then
        if exists_project_in_pootle "$1"; then
            logt 1 "Pootle project '$projectCode' already exists. Aborting..."
        else
            logt 1 "Provisioning new project '$projectCode' ($projectName) in pootle"
            create_pootle_project $projectCode "$projectName"
            initialize_project_files $projectCode "$projectName"
            notify_pootle $projectCode
        fi
    else
        logt 1 "Unable to create Pootle project '$projectCode' : pootle server is down. Please start it, then rerun this command"
    fi;
}

# main function which loads api functions, then configuration, and then invokes logic according to arguments
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
		src2pootle
		pootle2src
	elif [ $UPDATE_POOTLE_DB ]; then
		src2pootle
	elif [ $RESCAN_FILES ]; then
	    uniformize_pootle_paths
	elif [ $MOVE_PROJECT ]; then
	    rename_pootle_project $2 $3
    elif [ $UPLOAD ]; then
	    upload_translations $2 $3
    elif [ $NEW_PROJECT ]; then
	    add_project_in_pootle $2 "$3"
	elif [ $BACKPORT ]; then
	    backport_all
	fi

	[ ! $HELP ] &&	echo "$product [DONE]"
}

main "$@"
