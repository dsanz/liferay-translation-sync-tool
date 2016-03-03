# top level function to add a new empty project in pootle
function add_pootle_project_action() {
	projectCode="$1"
	projectName="$2"
	open_session="$3"

	if is_pootle_server_up; then
		if exists_project_in_pootle "$1"; then
			logt 1 "Pootle project '$projectCode' already exists. Aborting..."
		else
			logt 1 "Provisioning new project '$projectCode' ($projectName) in pootle"
			create_pootle_project $projectCode "$projectName" "$open_session"
			initialize_project_files $projectCode
			notify_pootle $projectCode
			restore_file_ownership
		fi
	else
		logt 1 "Unable to create Pootle project '$projectCode' : pootle server is down. Please start it, then rerun this command"
	fi;
}
