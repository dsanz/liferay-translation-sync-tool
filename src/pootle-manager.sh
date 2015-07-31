#!/bin/bash

# Author:		Milan Jaros, Daniel Sanz, Alberto Montero

# single point for loading all functions defined in the (low-level) api files as well as user-level APIs
function load_api() {
	# load environment from an explicitly git-ignored file
	[[ -f setEnv.sh ]] && . setEnv.sh

	# Load base APIs
	. api/api-base.sh
	. api/api-config.sh
	. api/api-git.sh
	. api/api-http.sh
	. api/api-db.sh
	. api/api-properties.sh
	. api/api-version.sh
	. api/api-project.sh
	. api/api-project-provisioning.sh
	. api/api-quality.sh
	. api/api-mail.sh
	. backporter-api/api-files.sh
	. backporter-api/api-git.sh
	. backporter-api/api-properties.sh

	# Load APIs
	. pootle-api/to_pootle.sh
	. pootle-api/to_pootle-file_poster.sh
	. pootle-api/to_liferay.sh
	. pootle-api/api-pootle-base.sh
	. pootle-api/api-pootle-project-add.sh
	. pootle-api/api-pootle-project-delete.sh
	. pootle-api/api-pootle-project-fix-path.sh
	. pootle-api/api-pootle-project-provisioning.sh
	. pootle-api/api-pootle-project-rename.sh
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
# - updates any translation committed to liferay source code since last pootle2src sync (pootle built-in
#     'update-translation-projects' can't be used due to a pootle bug, we do this with curl)

# preconditions:
#  . project must exist in pootle, same 'project code' than git source dir (for plugins)
#  . portal/plugin sources are available and are under git control
function src2pootle() {
	loglc 1 $RED "Begin Sync[Liferay source code -> Pootle]"
	display_projects
	backup_db
	update_pootle_db_from_templates
	pull_source_code
	clean_temp_input_dirs
	post_language_translations # bug #1949
	restore_file_ownership
	refresh_stats
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
# - creates a Pull Request for each involved git root, sent to a different reviewer.
# all the process is logged
function pootle2src() {
	loglc 1 $RED "Begin Sync[Pootle -> Liferay source code]"
	display_projects
	pull_source_code
	clean_temp_output_dirs
	export_pootle_translations_to_temp_dirs
	ascii_2_native
	restore_file_ownership
	process_translations
	do_commit false false "pootle exported keys"
	ant_build_lang
	do_commit true true "ant build-lang"
	loglc 1 $RED "End Sync[Pootle -> Liferay source code]"
}

function display_projects() {
	display_configured_projects
	display_AP_projects
}

# spread translations from a source project to the other ones within the same branch
# source project translations will be exported from pootle into PODIR
# source project git root will be pulled from upstream
# then, source project translations from PODIR are backported into target projects
# the target projects are all projects sharing the same git_root with the source project
# result is committed
#
# $1 is the source project code
function spread_translations() {
	source_project="$1"
	# we'll use the pootle export folder as source for the copy. This avoids polluting
	# the destination git root with data exported from the source project, which would
	# make those changes to be committed. We don't like that, we just need translations
	# in the destination project
	source_dir="$PODIR/$source_project"
	git_root="${AP_PROJECT_GIT_ROOT["$source_project"]}"
	logt 1 "Preparing to spread translations from project $source_project to the rest of projects under $git_root"

	# no need to call checkgit as source folder is not under git control
	# target dir is assumed to be on the right branch
	#check_git "${AP_PROJECT_GIT_ROOT[$source_project]}" "${AP_PROJECT_GIT_ROOT[$target_project]}" "master" "master"

	# this will export all source project translations into $source_dir
	clean_temp_output_dirs
	export_pootle_project_translations_to_temp_dirs $source_project
	# make sure we get the latest templates & translations from source code
	goto_branch_tip $git_root

	# iterate all projects in the same git root and backport to them
	project_list="$(echo ${AP_PROJECTS_BY_GIT_ROOT["$git_root"]} | sed 's: :\n:g' | sort)"
	while read target_project; do
		if [[ $target_project != $source_project ]]; then
			target_dir="${AP_PROJECT_SRC_LANG_BASE["$target_project"]}"
			# don't need further processing on pootle exported tranlations. The backporter will discard untranslated keys
			backport_project "$source_project > $target_project" "$source_dir" "$target_dir"
		fi
	done <<< "$project_list"

	# this function was designed for the backporter but can be used here
	# call it once as we are in just a single git root. Source project translations remain untouched.
	do_commit=0
	commit_result "$git_root" "$git_root"
}

function backport_all() {
	loglc 1 $RED "Begin backport process"
	display_projects

	use_git=0
	do_commit=0
	source_branch="$1"
	target_branch="$2"

	# prepare git for all base-paths
	logt 1 "Preparing involved directories"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		check_git "$base_src_dir" "$(get_ee_target_dir $base_src_dir)" "$source_branch" "$target_branch"
	done

	# backport is done on a project basis
	logt 1 "Backporting"
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		logt 2 "$project"
		source_dir="${AP_PROJECT_SRC_LANG_BASE["$project"]}"
		target_dir=$(get_ee_target_dir $source_dir)
		backport_project "$project" "$source_dir" "$target_dir"
	done;

	# commit result is again done on a base-path basis
	logt 1 "Committing backport process results"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		commit_result  "$base_src_dir" "$(get_ee_target_dir $base_src_dir)"
	done

	loglc 1 $RED "End backport process"
}

function upload_translations() {
	loglc 1 $RED  "Uploading $2 translations for project $1"
	backup_db
	post_file $1 $2
	loglc 1 $RED "Upload finished"
}

function upload_derived_translations() {
	project="$1"
	derived_locale="$2"
	parent_locale="$3"
	loglc 1 $RED  "Uploading $derived_locale (derived language) translations for project $project"
	backup_db
	post_derived_translations $project $derived_locale $parent_locale
	loglc 1 $RED "Upload finished"
}

function check_quality() {
	loglc 1 $RED "Begin Quality Checks"
	display_projects
	clean_temp_output_dirs
	export_pootle_translations_to_temp_dirs
	ascii_2_native
	run_quality_checks
	loglc 1 $RED "End Quality Checks"
}

# main function which loads api functions, then configuration, and then invokes logic according to arguments
main() {
	load_api
	echo "[START] $product"
	load_config
	resolve_params $@

	# most operations need (or will need) the AP project list
	[ ! $HELP ] && read_projects_from_sources

	if [ $UPDATE_REPOSITORY ]; then
		if [ $UPDATE_POOTLE_DB ]; then
			src2pootle
		fi
		pootle2src
	elif [ $UPDATE_POOTLE_DB ]; then
		src2pootle
	elif [ $RESCAN_FILES ]; then
		uniformize_pootle_paths
	elif [ $MOVE_PROJECT ]; then
		rename_pootle_project $2 $3
	elif [ $UPLOAD ]; then
		upload_translations $2 $3
	elif [ $UPLOAD_DERIVED ]; then
		upload_derived_translations $2 $3 $4
	elif [ $NEW_PROJECT ]; then
		add_project_in_pootle $2 "$3"
	elif [ $DELETE_PROJECT ]; then
		delete_project_in_pootle $2
	elif [ $BACKPORT ]; then
		backport_all $2 $3
	elif [ $QA_CHECK ]; then
		check_quality
	elif [ $RESTORE_BACKUP ]; then
		restore_backup $2;
	elif [ $LIST_PROJECTS ]; then
		display_projects;
	elif [ $PROVISION_PROJECTS ]; then
		provision_projects;
	elif [ $SPREAD_TRANSLATIONS ]; then
		spread_translations $2;
	fi

	if [[ -z ${LR_TRANS_MGR_TAIL_LOG+x} ]]; then
		kill $tail_log_pid
	fi;

	send_email $@

	[ ! $HELP ] &&	echo "[DONE] $product"
}

main "$@"
