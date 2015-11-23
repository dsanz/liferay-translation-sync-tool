#!/bin/sh

# top level function to add a new empty project in pootle
function add_project_in_pootle() {
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

function create_pootle_project() {
	projectCode="$1"
	projectName="$2"
	open_session="$3"

	logt 2 "Creating empty pootle project with code $projectCode"
	if [[ ${open_session+1} ]]; then
		logt 3 "Reusing existing pootle session"
	else
		start_pootle_session
	fi;
	# this creates the pootle project
	logt 3 -n "Posting new project form"
	status_code=$(curl $CURL_OPTS -w "%{http_code}" -d "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`"\
        -d "form-TOTAL_FORMS=1" -d "form-INITIAL_FORMS=0" -d "form-MAX_NUM_FORMS=1000"\
        -d "form-0-id=" -d "form-0-code=$projectCode" -d "form-0-fullname=$projectName"\
        -d "form-0-checkstyle=standard" -d "form-0-localfiletype=properties" -d "form-0-treestyle=gnu" \
        -d "form-0-source_language=2" -d "form-0-ignoredfiles=" -d "changeprojects=Save Changes"\
        "$PO_SRV/admin/projects.html" 2> /dev/null)
	log -n " ($status_code)"
	[[ $status_code == "200" ]]
	check_command

	if [[ ${open_session+1} ]]; then
		logt 3 "Keeping existing pootle session"
	else
		close_pootle_session
	fi;
}

function notify_pootle() {
	projectCode="$1"
	logt 2 "Notifying pootle about the new project"
	call_manage "update_translation_projects" "--project=$projectCode"
}

function initialize_project_files() {
	projectCode="$1"
	logt 3 "Initializing language files for $projectCode"

	locales=$(get_locales_from_source $PORTAL_PROJECT_ID)

	clean_dir "$PODIR/$projectCode"

	logt 4 -n "Creating template file"
	touch "$PODIR/$projectCode/$FILE.$PROP_EXT"
	check_command

	for locale in $locales; do
		filename="$FILE$LANG_SEP$locale.$PROP_EXT"
		logt 4 -n "Creating $filename"
		touch "$PODIR/$projectCode/$filename"
		check_command
	done;
}
#form-35-id:
#form-35-code:periquito-portlet
#form-35-fullname:Portlet de Periquito
#form-35-checkstyle:standard
#form-35-localfiletype:properties
#form-35-treestyle:gnu
#form-35-source_language:2
#form-35-ignoredfiles:
#changeprojects:Save Changes
#
#csrfmiddlewaretoken:6f182fe672be1094f318b13b55d7bd03
#form-TOTAL_FORMS:36
#form-INITIAL_FORMS:35
#form-MAX_NUM_FORMS: