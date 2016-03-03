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

	# Load Actions
	. actions/statistics-action.sh
	. actions/export/export_translations_into_zip_action.sh
	. actions/export/backport_all_action.sh
	. actions/import/upload_translations_action.sh
	. actions/import/upload_derived_translations_action.sh
	. actions/provisioning/add_pootle_project_action.sh
	. actions/provisioning/delete_pootle_project_action.sh
	. actions/provisioning/display_source_projects_action.sh
	. actions/provisioning/move_pootle_project_action.sh
	. actions/provisioning/provision_projects_actions.sh
	. actions/provisioning/regenerate_file_stores_action.sh
	. actions/provisioning/rescan_files_action.sh
	. actions/sync/sync_sources_from_pootle_action.sh
	. actions/sync/sync_pootle_from_sources_action.sh
	. actions/sync/spread_translations_action.sh

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
	display_source_projects_action
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
	display_source_projects_action
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

function check_quality() {
	loglc 1 $RED "Begin Quality Checks"
	display_source_projects_action
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

	# sync source/pootle actions
	if   [ $SYNC_SOURCES ]; then sync_sources_from_pootle_action
	elif [ $SYNC_POOTLE ];  then sync_pootle_from_sources_action
	elif [ $SPREAD_TRANSLATIONS ]; then spread_translations_action $2 "$3"

	# export translation actions
	elif [ $GENERATE_ZIP ]; then generate_zip_from_translations_action
	elif [ $BACKPORT ]; then backport_all_action $2 $3

	# import translations actions
	elif [ $UPLOAD ]; then upload_translations_action $2 $3
	elif [ $UPLOAD_DERIVED ]; then upload_derived_translations_action $2 $3 $4

	# project provisioning actions
	elif [ $MOVE_PROJECT ]; then move_pootle_project_action $2 $3
	elif [ $NEW_PROJECT ]; then add_pootle_project_action $2 "$3"
	elif [ $DELETE_PROJECT ]; then delete_pootle_project_action $2
	elif [ $LIST_PROJECTS ]; then display_source_projects_action
	elif [ $PROVISION_PROJECTS ]; then provision_projects_action
	elif [ $PROVISION_PROJECTS_ONLY_CREATE ]; then provision_projects_only_create_action
	elif [ $PROVISION_PROJECTS_ONLY_DELETE ]; then provision_projects_only_delete_action
	elif [ $PROVISION_PROJECTS_DUMMY ]; then provision_projects_dummy_action
	elif [ $RESCAN_FILES ]; then rescan_files_action
	elif [ $FIX_PODIR ]; then regenerate_file_stores_action

	# data backup actions
	elif [ $RESTORE_BACKUP ]; then restore_backup $2;
	elif [ $CREATE_BACKUP ]; then backup_db;
	elif [ $LIST_BACKUPS ]; then list_backups;

	# miscellaneous actions
	elif [ $QA_CHECK ]; then check_quality
	elif [ $DISPLAY_STATS ]; then
		read_projects_from_sources
		display_stats;
	fi

	if [[ -z ${LR_TRANS_MGR_TAIL_LOG+x} ]]; then
		kill $tail_log_pid
	fi;

	send_email $@

	[ ! $HELP ] &&	echo "[DONE] $product"
}

main "$@"
