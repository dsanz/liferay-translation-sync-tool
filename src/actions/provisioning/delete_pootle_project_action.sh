# top level function to delete a project in pootle
function delete_pootle_project_action() {
	projectCode="$1"
	open_session="$2"

	if is_pootle_server_up; then
		if exists_project_in_pootle "$1"; then
			logt 1 "Deleting project '$projectCode' in pootle"
			delete_pootle_project $projectCode $open_session
		else
			logt 1 "Pootle project '$projectCode' does not exist. Aborting..."
		fi
	else
		logt 1 "Unable to delete Pootle project '$projectCode': pootle server is down. Please start it, then rerun this command"
	fi;
}