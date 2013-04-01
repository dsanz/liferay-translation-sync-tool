#!/bin/bash

####
## Pootle server communication
####

. common-functions.sh

# to Pootle

    close_pootle_session() {
	# get logout page and delete cookies
	echo -n "    Closing pootle session... "
	curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" "$PO_SRV/accounts/logout" > /dev/null
	check_command
	#[ -f "$PO_COOKIES" ] && rm "$PO_COOKIES"
    }

    start_pootle_session() {
	echo_white "  Opening new pootle session"
	close_pootle_session
	# 1. get login page (and cookies)
	echo -n "    Accessing Pootle login page... "
	curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" "$PO_SRV/accounts/login" > /dev/null
	check_command
	# 2. post credentials, including one received cookie
	echo -n "    Posting credentials... "
 	curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" -d "username=$PO_USER;password=$PO_PASS;csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" "$PO_SRV/accounts/login" > /dev/null
	check_command
    }

    upload_suggestions() {
	echo_cyan "[`date`] Uploading auto-translations as suggestions..."
	start_pootle_session
	projects=`ls $TMP_PROP_IN_DIR`
	for project in $projects;
	do
		echo_white "  $project: uploading automatic translations as suggestions"
		languages=`ls "$TMP_PROP_IN_DIR/$project/"`
		for language in $languages;
		do
			if [ -f "$TMP_PROP_IN_DIR/$project/$language" ] && [ "$FILE.$PROP_EXT" != "$language" ]; then
				l=`echo $language  | cut -f2- -d _ | cut -f1 -d .`
				#echo_white "Uploading: curl -b $PO_COOKIES -c $PO_COOKIES -F \"file=@$TMP_PROP_IN_DIR/$project/aut/$language\" -F \"overwrite=suggest\" -F \"do_upload=upload\" -F 	\"csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`\" \"$PO_SRV/$l/$project/\""
				echo -n "    Uploading suggestions for $project/$l... "
				curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" -F "file=@$TMP_PROP_IN_DIR/$project/aut/$language" -F "overwrite=suggest" -F "do_upload=upload" -F "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" "$PO_SRV/$l/$project/" > /dev/null
				check_command
			fi
 		done
	done

	echo_white "  Closing pootle session"
	close_pootle_session
    }

    update_pootle_db() {
	echo_cyan "[`date`] Updating pootle database..."
	rm -f "$PODIR/$project/*"
	projects=`ls $TMP_PROP_IN_DIR`
	for project in $projects;
	do
		echo_white "  $project: copying project files"
		cp "$TMP_PROP_IN_DIR/$project/${FILE}.$PROP_EXT" "$PODIR/$project"
		# Update database as well as file system to reflect the latest version of translation templates
		echo_white "  $project: updating Pootle templates"
		$POOTLEDIR/manage.py update_from_templates --project="$project"	-v 0
	done
    }

	prepare_input_dirs() {
		echo_cyan "[`date`] Preparing project input working dirs..."
		projects_count=$((${#PROJECTS[@]} - 1))
		for i in `seq 0 $projects_count`;
		do
			project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
			echo_white "  $project: creating / cleaing dirs"
			clean_dir "$TMP_PROP_IN_DIR/$project"
			clean_dir "$TMP_PROP_IN_DIR/$project/aut"
			clean_dir "$TMP_PROP_IN_DIR/$project/svn"
		done
	}