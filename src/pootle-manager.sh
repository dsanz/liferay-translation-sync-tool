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
	clean_temp_output_dirs
	export_pootle_translations_to_temp_dirs
	ascii_2_native
	restore_file_ownership
	process_translations
	do_commit false false "Translations sync from translate.liferay.com"
	build_lang
	do_commit true true "build-lang"
	loglc 1 $RED "End Sync[Pootle -> Liferay source code]"
}

function display_projects() {
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
	project_list="$2"
	logt 1 "Preparing to spread translations from project $source_project"

	# try to get git root from source project first
	git_root="${AP_PROJECT_GIT_ROOT["$source_project"]}"
	# try to get source dir from auto-provisioned stuff indexing by source_project
	source_dir="${AP_PROJECT_SRC_LANG_BASE["$source_project"]}"

	# as source project might not exist in sources, let's check and try plan B instead
	# Plan B: get git root from destination project. In this case, destination project
	# has to be explicitly listed

	if [[ $project_list == "" && $git_root == "" ]]; then
		logc $RED "There is no way to compute git root dir. Please provide either an existing source project or specify a list of destination projects"
		return;
	fi;

    if [[ $git_root == "" ]]; then
		first_project="$(echo $project_list | cut -d " " -f1)"
		logt 2 "I can not compute git root. I'll use the git root of first destination project: $first_project"
		git_root="${AP_PROJECT_GIT_ROOT["$first_project"]}"
	fi;

	if [[ $project_list == "" ]]; then
		logt 2 "Source project does not exist in $git_root. I'll use all projects"
		project_list=${AP_PROJECTS_BY_GIT_ROOT["$git_root"]}
	fi;

	if [[ $source_dir == "" ]]; then
		logt 2 "Source project does not exist in $git_root. I'll create a temporary location for it "
		logt -n 4 "Creating $git_root/temp/$project_code"
		mkdir --parents "$git_root/temp/$project_code"
		check_command
		add_AP_project "$source_project" "$source_project" "$git_root" "temp/$project_code" "temp/$project_code"
		source_dir="${AP_PROJECT_SRC_LANG_BASE["$source_project"]}"
	fi;

	logt 2 "Translations will be spread as follows:"
	logt 3 "Source project: $source_project "
	logt 3 "Source dir: $source_dir "
	logt 3 "Destination project(s): $project_list  (Source project will be excluded from this list if exists)"
	logt 3 "Git root: $git_root"

	project_list="$(echo "$project_list" | sed 's: :\n:g' | sort)"

	# no need to call checkgit as source folder is not under git control
	# target dir is assumed to be on the right branch
	#check_git "${AP_PROJECT_GIT_ROOT[$source_project]}" "${AP_PROJECT_GIT_ROOT[$target_project]}" "master" "master"

	# make sure we get the latest templates & translations from source code
	goto_branch_tip $git_root

	# this will export all source project translations into $source_dir as we do in pootle2src, but only for source_project
	clean_temp_output_dirs
	export_pootle_project_translations_to_temp_dirs $source_project
	process_project_translations $source_project false
	# don't forget to copy the Language.properties itself to the source dir. In a regular export this is not required.
	logt 2 -n "Copying language template from $source_project export to the source code"
	cp -f  "$PODIR/$project/${FILE}.$PROP_EXT" "$source_dir"
	check_command
	restore_file_ownership

	logt 1 "Source project has been exported. Now I will spread its translations to the other projects in $git_root"

	# iterate all projects in the destination project list and 'backport' to them
	while read target_project; do
		if [[ $target_project != $source_project ]]; then
			target_dir="${AP_PROJECT_SRC_LANG_BASE["$target_project"]}"
			# don't need further processing on pootle exported tranlations. The backporter will discard untranslated keys
			unset K
			unset T
			unset L;
			declare -gA T;
			declare -ga K;
			declare -ag L;
			backport_project "$source_project > $target_project" "$source_dir" "$target_dir"
		fi
	done <<< "$project_list"

	# commit_result function was designed for the backporter but can be used here
	# it must be called once as we are in just a single git root. Source project translations remain untouched.
	# before committing, lets revert source project changes. This way, just spread translations will be committed
	logt 2 "Resetting $source_project changes before committing"
	cd $source_dir
	for language_file in $(ls); do
		logt 3 -n "git checkout HEAD $language_file"
		git checkout HEAD $language_file;
		check_command
	done
	do_commit=0

	# tweak a bit the arrays expected by commit_result so that spread commit message makes sense.
	branch["$source_project"]="$source_project"
	commit["$source_project"]="pootle"
	cd $target_dir
	branch["$git_root"]="$target_project"
	commit["$git_root"]=$(git rev-parse HEAD)
	commit_result "$source_project" "$git_root"
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

	if [ $UPDATE_REPOSITORY ]; then
		read_projects_from_sources
		if [ $UPDATE_POOTLE_DB ]; then
			src2pootle
		fi
		pootle2src
	elif [ $UPDATE_POOTLE_DB ]; then
		read_projects_from_sources
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
	elif [ $CREATE_BACKUP ]; then
		backup_db;
	elif [ $LIST_PROJECTS ]; then
		read_projects_from_sources
		display_projects;
	elif [ $PROVISION_PROJECTS ]; then
		read_projects_from_sources
		provision_projects true true
	elif [ $PROVISION_PROJECTS_ONLY_CREATE ]; then
		read_projects_from_sources
		provision_projects true false
	elif [ $PROVISION_PROJECTS_ONLY_DELETE ]; then
		read_projects_from_sources
		provision_projects false true
	elif [ $PROVISION_PROJECTS_DUMMY ]; then
		read_projects_from_sources
		provision_projects false false
	elif [ $FIX_PODIR ]; then
		fix_podir
	elif [ $LIST_BACKUPS ]; then
		list_backups;
	elif [ $SPREAD_TRANSLATIONS ]; then
		read_projects_from_sources
		spread_translations $2 "$3";
	fi

	if [[ -z ${LR_TRANS_MGR_TAIL_LOG+x} ]]; then
		kill $tail_log_pid
	fi;

	send_email $@

	[ ! $HELP ] &&	echo "[DONE] $product"
}

main "$@"
