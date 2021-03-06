#!/bin/bash

# Author:		Milan Jaros, Daniel Sanz, Alberto Montero

# single point for loading all functions defined in the (low-level) api files as well as user-level APIs
function load_api() {
	# load environment from an explicitly git-ignored file
	[[ -f setEnv.sh ]] && . setEnv.sh

	. api/core/api_properties.sh
	. api/core/api_source_code_project_provisioning.sh
	. api/core/api_quality.sh
	. api/pootle/infrastructure/api_pootle_base.sh
	. api/pootle/infrastructure/api_pootle_db.sh
	. api/pootle/infrastructure/api_pootle_http.sh
	. api/pootle/project/api_pootle_project_add.sh
	. api/pootle/project/api_pootle_project_delete.sh
	. api/pootle/project/api_pootle_project_fix_path.sh
	. api/pootle/project/api_pootle_project_provisioning.sh
	. api/pootle/project/api_pootle_project_rename.sh

	. api/util/api_base.sh
	. api/util/api_config.sh
	. api/util/api_git.sh
	. api/util/api_mail.sh
	. api/util/api_version.sh

	. api/sync/backport/api_sync_backport.sh
	. api/sync/backport/api_sync_backport_git.sh
	. api/sync/api_sync.sh
	. api/sync/api_sync_lang_files.sh
	. api/sync/to_source/api_sync_to_source_build_sources.sh
	. api/sync/to_source/api_sync_to_source_export.sh
	. api/sync/to_source/api_sync_to_source_git.sh
	. api/sync/to_source/api_sync_to_source_misc.sh
	. api/sync/to_pootle/api_sync_to_pootle_misc.sh
	. api/sync/to_pootle/api_sync_to_pootle_update_from_templates.sh
	. api/sync/to_pootle/api_sync_to_pootle_upload.sh

	# Load Actions
	. actions/backup/create_backup_action.sh
	. actions/backup/list_backups_action.sh
	. actions/backup/restore_backup_action.sh
	. actions/export/export_translations_into_zip_action.sh
	. actions/export/backport_all_action.sh
	. actions/import/upload_translations_action.sh
	. actions/import/upload_derived_translations_action.sh
	. actions/misc/check_quality_action.sh
	. actions/misc/display_stats_action.sh
	. actions/provisioning/add_pootle_project_action.sh
	. actions/provisioning/delete_pootle_project_action.sh
	. actions/provisioning/display_source_projects_action.sh
	. actions/provisioning/merge_pootle_projects_action.sh
	. actions/provisioning/move_pootle_project_action.sh
	. actions/provisioning/provision_projects_actions.sh
	. actions/provisioning/regenerate_file_stores_action.sh
	. actions/provisioning/rescan_files_action.sh
	. actions/sync/sync_action.sh
	. actions/sync/spread_translations_action.sh

	declare -xgr HOME_DIR="$(dirname $(readlink -f $BASH_SOURCE))"
}

# main function which loads api functions, then configuration, and then invokes logic according to arguments
main() {
	load_api
	echo "[START] $product"
	load_config
	resolve_params $@

	# sync source/pootle actions
	if   [ $SYNC ]; then sync_action
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
	elif [ $MERGE_PROJECTS ]; then merge_pootle_projects_action $2 "$3"
	elif [ $PROVISION_PROJECTS ]; then provision_projects_action
	elif [ $PROVISION_PROJECTS_ONLY_CREATE ]; then provision_projects_only_create_action
	elif [ $PROVISION_PROJECTS_ONLY_DELETE ]; then provision_projects_only_delete_action
	elif [ $PROVISION_PROJECTS_DUMMY ]; then provision_projects_dummy_action
	elif [ $RESCAN_FILES ]; then rescan_files_action
	elif [ $FIX_PODIR ]; then regenerate_file_stores_action

	# data backup actions
	elif [ $RESTORE_BACKUP ]; then restore_backup_action $2;
	elif [ $CREATE_BACKUP ]; then create_backup_action;
	elif [ $LIST_BACKUPS ]; then list_backups_action;

	# miscellaneous actions
	elif [ $QA_CHECK ]; then check_quality_action
	elif [ $DISPLAY_STATS ]; then display_stats_action;
	fi

	if [[ -z ${LR_TRANS_MGR_TAIL_LOG+x} ]]; then
		kill $tail_log_pid
	fi;

	send_email $@

	[ ! $HELP ] &&	echo "[DONE] $product"
}

main "$@"
