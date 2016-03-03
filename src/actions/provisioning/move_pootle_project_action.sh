function move_pootle_project_action() {
	currentName="$1"
	newName="$2"
	if [[ "$currentName" == "" || "$newName" == "" || "$currentName" == "$newName" ]]; then
		logt 1 "Unable to rename Pootle project \"$currentName\" to \"$newName\". Either names are equal or some of them are empty"
	elif is_pootle_server_up; then
		logt 1 "Unable to rename Pootle project: pootle server is up and running. Please stop it, then rerun this command"
	else
		logt 1 "Renaming Pootle project \"$currentName\" to \"$newName\""
		backup_db
		logt 2 "Updating database tables"
		rename_pootle_store_store_entries $currentName $newName
		rename_pootle_app_directory_entries $currentName $newName
		rename_pootle_app_translationproject_entries $currentName $newName
		rename_pootle_app_project_entries $currentName $newName
		rename_pootle_notifications_notice_entries $currentName $newName
		logt 2 "Renaming filesystem elements"
		logt 3 -n "mv $PODIR/$currentName $PODIR/$newName"
		mv $PODIR/$currentName $PODIR/$newName > /dev/null 2>&1
		check_command
		logt 1 "Pootle project renamed. Please start up Pootle server and check $PO_SRV/projects/$newName"
	fi
}
