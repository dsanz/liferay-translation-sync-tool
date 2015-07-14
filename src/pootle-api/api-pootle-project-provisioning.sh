
# traditional, http way to check for pootle project existence
function exists_project_in_pootle() {
	wget --spider "$PO_SRV/projects/$1" 2>&1 | grep 200 > /dev/null
}

function exists_project_in_pootle_DB() {
	project_code="$1"
	exists=false;
	for pootle_project_code in "${!POOTLE_PROJECT_CODES[@]}";
	do
		if [[ "$project_code" == "$pootle_project_code" ]]; then
			exists=true
			break;
		fi;
	done;
	$exists
}

function read_pootle_projects() {
	logt 2 "Reading projects from pootle DB"
	unset POOTLE_PROJECT_CODES
	declare -xga POOTLE_PROJECT_CODES;
	read -ra POOTLE_PROJECT_CODES <<< "$(get_pootle_project_codes)"
}

function create_missing_projects_in_pootle() {
	logt 2 "Creating missing projects in pootle"
	for ap_project_code in "${!AP_PROJECT_NAMES[@]}";
	do
		if exists_project_in_pootle_DB $ap_project_code; then
			logt 3 "Project $ap_project_code exists in pootle"
		else
			logt 3 "Project $ap_project_code does not exist in pootle"
		fi;
	done;
}

function provision_projects() {
	logt 1 "Provisioning projects from sources"
	read_pootle_projects
	create_missing_projects_in_pootle
	##delete_old_projects_in_pootle
}

