function regenerate_file_stores_action() {
	logt 1 "Regenerating project stores. Location: $PODIR"
	read_pootle_projects_and_locales
	for pootle_project_code in "${POOTLE_PROJECT_CODES[@]}";
	do
		regenerate_file_stores $pootle_project_code
	done;
}

function regenerate_file_stores() {
	project_code="$1"
	logt 2 " $project_code: Regenerating project stores from pootle DB into po dir"
	initialize_project_files $project_code
	sync_stores $project_code
	restore_file_ownership
}
