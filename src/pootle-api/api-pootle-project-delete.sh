# top level function to delete a project in pootle
function delete_project_in_pootle() {
	projectCode="$1"
	projectName="$2"

	if is_pootle_server_up; then
		if exists_project_in_pootle "$1"; then
			logt 1 "Deleting project '$projectCode' ($projectName) in pootle"
			delete_pootle_project $projectCode "$projectName"
		else
			logt 1 "Pootle project '$projectCode' does not exist. Aborting..."
		fi
	else
		logt 1 "Unable to delete Pootle project '$projectCode' : pootle server is down. Please start it, then rerun this command"
	fi;
}


function delete_pootle_project() {
	projectCode="$1"

	logt 2 "Deleting pootle project $projectCode"
	start_pootle_session

	id=$(get_pootle_project_id_from_code $projectCode)
	projectName=$(get_pootle_fullname_from_code $projectCode)

	# this deletes the pootle project
	logt 3 -n "Posting delete project form (id: $id, fullname: $projectName)"
	curl $CURL_OPTS -d "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`"\
        -d "form-TOTAL_FORMS=1" -d "form-INITIAL_FORMS=0" -d "form-MAX_NUM_FORMS=1000"\
        -d "form-0-id=$id" -d "form-0-code=$projectCode" -d "form-0-fullname=$projectName"\
        -d "form-0-checkstyle=standard" -d "form-0-localfiletype=properties" -d "form-0-treestyle=gnu" \
        -d "form-0-source_language=2" -d "form-0-ignoredfiles=" -d "form-0-DELETE=on" \
        -d "changeprojects=Save Changes" \
        "$PO_SRV$path/admin/projects.html"
	check_command
	close_pootle_session
}
