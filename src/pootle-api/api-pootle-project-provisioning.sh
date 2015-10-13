declare -xga POOTLE_PROJECT_DELETION_WHITELIST_REGEXS=(sync terminology)

# traditional, http way to check for pootle project existence
function exists_project_in_pootle() {
	wget --spider "$PO_SRV/projects/$1" 2>&1 | grep 200 > /dev/null
}

function exists_project_in_pootle_DB() {
	project_code="$1"
	exists=false;
	for pootle_project_code in "${POOTLE_PROJECT_CODES[@]}";
	do
		if [[ "$project_code" == "$pootle_project_code" ]]; then
			exists=true
			break;
		fi;
	done;
	[ "$exists" = true ]
}

function exists_project_in_AP_list() {
	project_code="$1"
	exists=false;
	for ap_project_code in "${!AP_PROJECT_NAMES[@]}";
	do
		if [[ "$project_code" == "$ap_project_code" ]]; then
			exists=true
			break;
		fi;
	done;
	[ "$exists" = true ]
}

function read_pootle_projects() {
	logt 2 "Reading projects from pootle DB"
	unset POOTLE_PROJECT_CODES
	declare -xga POOTLE_PROJECT_CODES;
	read -ra POOTLE_PROJECT_CODES <<< $(get_pootle_project_codes)
}

function create_missing_projects_in_pootle() {
	logt 2 "Creating missing projects in pootle"
	declare -a projects_to_create;
	for ap_project_code in "${!AP_PROJECT_NAMES[@]}";
	do
		if ! exists_project_in_pootle_DB $ap_project_code; then
			projects_to_create[${#projects_to_create[@]}]=$ap_project_code
		fi;
	done;
	logt 3 "Will create following projects in pootle"
	for ap_project_code in "${projects_to_create[@]}"; do
		log -n "  $ap_project_code"
	done;
	log

	logt 3 "[Start] Provisioning projects (creation)"
	start_pootle_session
#TODO: iterate over the array once tests are done
	provision_full_project ${projects_to_create[0]}
	close_pootle_session
	logt 3 "[End] Provisioning projects (creation)"
}

function is_whitelisted() {
	project_code="$1"
	whitelisted=false
	for regex in "${POOTLE_PROJECT_DELETION_WHITELIST_REGEXS[@]}";
	do
		if [[ "$project_code" =~ $regex ]]; then
			whitelisted=true;
			break;
		fi;
	done;
	[ "$whitelisted" = true ]
}

function delete_old_projects_in_pootle() {
	logt 2 "Deleting obsolete projects in pootle"
	declare -a projects_to_delete;
	declare -a projects_whitelisted;
	for pootle_project_code in "${POOTLE_PROJECT_CODES[@]}";
	do
		if ! exists_project_in_AP_list $pootle_project_code; then
			if is_whitelisted $pootle_project_code; then
				projects_whitelisted[${#projects_whitelisted[@]}]=$pootle_project_code
			else
				projects_to_delete[${#projects_to_delete[@]}]=$pootle_project_code
			fi
		fi;
	done;
	logt 3 "Will delete following projects in pootle"
	for ap_project_code in "${projects_to_delete[@]}"; do
		log -n "  $ap_project_code"
	done;
	log

	logt 3 "Won't delete following whitelisted projects in pootle"
	for ap_project_code in "${projects_whitelisted[@]}"; do
		log -n "  $ap_project_code"
	done;
	log

	logt 3 "[Start] Provisioning projects (deletion)"
	start_pootle_session
	for ap_project_code in "${projects_to_delete[@]}"; do
		delete_project_in_pootle ${ap_project_code} 0
	done;
 	close_pootle_session

	logt 3 "[End] Provisioning projects (deletion)"
}

function provision_projects() {
	logt 1 "Provisioning projects from sources"
	read_pootle_projects
	create_missing_projects_in_pootle
	delete_old_projects_in_pootle
}

function provision_full_project() {
	project_code="$1"

	logt 1 "Provisioning full pootle project $project_code (${AP_PROJECT_NAMES[$project_code]})"

	# create empty project in pootle
	add_project_in_pootle $project_code "${AP_PROJECT_NAMES[$project_code]}" 0

	# let pootle know the set of available key for that project
	logt 2 "Setting pootle project template"
	update_from_templates $project_code "${AP_PROJECT_SRC_LANG_BASE[$project_code]}"

	# provide translations from code
	logt 2 "Filling up project translations"
	cd "${AP_PROJECT_SRC_LANG_BASE[$project_code]}"
	files="$(ls ${FILE}${LANG_SEP}*.${PROP_EXT} 2>/dev/null)"
	for file in $files; do
		locale=$(get_locale_from_file_name $file)
		post_file_batch "$project_code" "$locale"
	done;
}