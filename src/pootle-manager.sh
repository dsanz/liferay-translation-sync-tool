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
	. api/api-pootle-base.sh
	. api/api-pootle-project-rename.sh
	. api/api-pootle-project-fix-path.sh
	. api/api-quality.sh
	. api/api-mail.sh
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
	logt 1 "Working project list by git root (${#PROJECT_NAMES[@]} projects, ${#GIT_ROOTS[@]} git roots) "
	for git_root in "${!GIT_ROOTS[@]}"; do
		project_list="$(echo ${PROJECTS_BY_GIT_ROOT["$git_root"]} | sed 's: :\n:g' | sort)"
		projects=$(echo "$project_list" | wc -l)
		logt 2 "Git root: $git_root ($projects projects). Sync branch: ${GIT_ROOTS[$git_root]}. Reviewer: ${PR_REVIEWER[$git_root]}"
		while read project; do
			logt 3 -n "$(printf "%-35s%s" "$project")"
			project_src="${PROJECT_SRC_LANG_BASE["$project"]}"
			log -n $project_src
			[ -d $project_src ]
			check_command
		done <<< "$project_list"
	done;
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
	for project in "${!PROJECT_NAMES[@]}"; do
		logt 2 "$project"
		source_dir="${PROJECT_SRC_LANG_BASE["$project"]}"
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

function add_project_in_pootle() {
	projectCode="$1"
	projectName="$2"

	if is_pootle_server_up; then
		if exists_project_in_pootle "$1"; then
			logt 1 "Pootle project '$projectCode' already exists. Aborting..."
		else
			logt 1 "Provisioning new project '$projectCode' ($projectName) in pootle"
			create_pootle_project $projectCode "$projectName"
			initialize_project_files $projectCode "$projectName"
			notify_pootle $projectCode
			restore_file_ownership
		fi
	else
		logt 1 "Unable to create Pootle project '$projectCode' : pootle server is down. Please start it, then rerun this command"
	fi;
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
	elif [ $BACKPORT ]; then
		backport_all $2 $3
	elif [ $QA_CHECK ]; then
		check_quality
	elif [ $RESTORE_BACKUP ]; then
		restore_backup $2;
	elif [ $LIST_PROJECTS ]; then
		display_projects;
	fi

	if [[ -z ${LR_TRANS_MGR_TAIL_LOG+x} ]]; then
		kill $tail_log_pid
	fi;

	send_email $@

	[ ! $HELP ] &&	echo "[DONE] $product"
}

main "$@"
