function delete_pootle_project() {
	projectCode="$1"
	open_session="$2"

	logt 2 "Deleting project $projectCode from pootle server"
	if [[ ${open_session+1} ]]; then
		logt 3 "Reusing existing pootle session"
	else
		start_pootle_session
	fi;

	id="$(get_pootle_project_id_from_code $projectCode)"
	projectName="$(get_pootle_project_fullname_from_code $projectCode)"

	# this deletes the pootle project
	logt 3 -n "Posting delete project form (id: $id, fullname: $projectName) to pootle server"
	curl $CURL_OPTS -d "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`"\
        -d "form-TOTAL_FORMS=1" -d "form-INITIAL_FORMS=1" -d "form-MAX_NUM_FORMS=1000"\
        -d "form-0-id=$id" -d "form-0-code=$projectCode" -d "form-0-fullname=$projectName"\
        -d "form-0-checkstyle=standard" -d "form-0-localfiletype=properties" \
        -d "form-0-treestyle=gnu" -d "form-0-source_language=2" -d "form-0-ignoredfiles=" \
        -d "form-0-DELETE=on" -d "changeprojects=Save Changes" \
        "$PO_SRV/admin/projects.html"
	check_command
	if [[ ${open_session+1} ]]; then
		logt 3 "Keeping existing pootle session"
	else
		close_pootle_session
	fi;

	# seems that above post does not delete files on disk. Let's do it
	logt 3 -n "Deleting project files on disk"
	rm -Rf $PODIR/$projectCode 2>&1 > /dev/null
	check_command
}

#form-9-id:105
#form-9-code:kk
#form-9-fullname:KkKk
#form-9-checkstyle:standard
#form-9-localfiletype:po
#form-9-treestyle:auto
#form-9-source_language:2
#form-9-ignoredfiles:
#form-9-DELETE:on