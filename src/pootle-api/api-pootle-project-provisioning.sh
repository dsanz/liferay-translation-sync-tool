
# traditional, http way to check for pootle project existence
function exists_project_in_pootle() {
	wget --spider "$PO_SRV/projects/$1" 2>&1 | grep 200 > /dev/null
}

function exists_project_in_pootle_() {
	project_code="$1"
	exists=false;
	for project in "${!POOTLE_PROJECT_CODES[@]}";
	do
		if [[ "$project_code" == "$project" ]]; then
			exists=true
			break;
		fi;
	done;
	[[ $exists ]]
}

function read_pootle_projects() {
	unset POOTLE_PROJECT_CODES
	declare -xga POOTLE_PROJECT_CODES;
	read -ra POOTLE_PROJECT_CODES <<< "$(get_pootle_project_codes)"
}

function provision_projects() {
	logt 1 "Provisioning projects from sources"
	create_missing_projects_in_pootle
	delete_old_projects_in_pootle
}

function create_missing_projects_in_pootle() {
	logt 2 "Creating missing projects in pootle"
	for project in "${!AP_PROJECT_NAMES[@]}";
	do
		if [[ ! exists_project_in_pootle_ $project ]]; then
			logt 3 "Project $project does not exist in pootle"
		else
			logt 3 "Project $project exists in pootle"
		fi;
	done
}
