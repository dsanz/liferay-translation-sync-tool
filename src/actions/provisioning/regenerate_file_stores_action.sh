function regenerate_file_stores_action() {
	logt 1 "Regenerating project stores. Location: $PODIR"
	read_pootle_projects_and_locales
	for pootle_project_code in "${POOTLE_PROJECT_CODES[@]}";
	do
		regenerate_file_stores $pootle_project_code
	done;
}

