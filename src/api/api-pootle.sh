#!/bin/bash

function call_manage() {
	command="$1"
	shift 1
	args="$@"

	python_path_arg=""
	[[ ! -z $POOTLE_PYTHONPATH ]] && python_path_arg="--pythonpath=$POOTLE_PYTHONPATH"

	settings_arg="";
	[[ ! -z $POOTLE_SETTINGS ]] && settings_arg="--settings=$POOTLE_SETTINGS"


	invoke="python $POOTLEDIR/manage.py $command $args $python_path_arg $settings_arg"
	logt 5 -n $invoke
	$invoke > /dev/null 2>&1
	check_command
}

function fix_pootle_path() {
	path="$1"
	correctPath="$2"
	filePath="$3"
	correctFilePath="$4"
	correctFileName="$5"

	logt 3 -n "Updating (pootle_path,file,name) columns in 'pootle_store_store' database table.";
	$MYSQL_COMMAND $DB_NAME -s -e "update pootle_store_store set pootle_path='$correctPath',file='$correctFilePath',name='$correctFileName' where pootle_path='$path'"; > /dev/null 2>&1
	check_command
	if [ -f $PODIR/$filePath ]; then
		logt 3 -n "Moving po file to $correctPath"
		mv $PODIR/$filePath $PODIR/$correctFilePath
		check_command
	elif [ -f $PODIR/$correctFilePath ]; then
		logt 3 "po file seems already ok"
	else
		logt 3 -n "Seems that no po file exist! Let's update from templates"
		locale=$(get_locale_from_file_name $correctFileName)
		project=$(echo $correctFilePath | cut -d '/' -f1)
		call_manage "update_from_templates" "--project=$project" "--language=$locale" "-v 0"
	fi
}

function fix_malformed_paths_having_dashes() {
	malformedPathsHavingDashes=$($MYSQL_COMMAND $DB_NAME -s -e "select pootle_path from pootle_store_store where pootle_path like '%Language-%';" | grep properties)
	for path in $malformedPathsHavingDashes; do
		# path has the form /locale/project/Language-locale.properties
		logt 2 "Fixing dashed path $path"
		# correctPath has the form /locale/project/Language_locale.properties
		correctPath=$(echo $path | sed 's/Language-/Language_/')
		# filePath has the form /project/Language-locale.properties
		filePath=$(echo $path | cut -d '/' -f3-)
		# correctFilePath has the form /project/Language-locale.properties
		correctFilePath=$(echo $filePath | sed 's/Language-/Language_/')
		# correctFileName has the form Language_locale.properties
		correctFileName=$(echo $correctFilePath | cut -d '/' -f2-)
		fix_pootle_path $path $correctPath $filePath $correctFilePath $correctFileName
	done;
}

function fix_malformed_paths_gnu() {
	malformedPathsGnu=$($MYSQL_COMMAND $DB_NAME -s -e "select pootle_path  path from pootle_store_store where name not like 'Language%' and name not like '%.po';" | grep properties)
	for path in $malformedPathsGnu; do
		# path has the form /locale/project/locale.properties
		logt 2 "Fixing GNU path $path"
		# correctPath has the form /locale/project/Language_locale.properties
		correctPath=$(echo $path | sed -r 's:(^.*/)([^\.]+\.properties)$:\1Language_\2:')
		# filePath has the form /project/locale.properties
		filePath=$(echo $path | cut -d '/' -f3-)
		# correctFilePath has the form /project/Language-locale.properties
		correctFilePath=$(echo $filePath | sed -r 's:(^.*/)([^\.]+\.properties)$:\1Language_\2:')
		# correctFileName has the form Language_locale.properties
		correctFileName=$(echo $correctFilePath | cut -d '/' -f2-)
		fix_pootle_path $path $correctPath $filePath $correctFilePath $correctFileName
	done;
}

function fix_malformed_paths() {
	fix_malformed_paths_having_dashes
	fix_malformed_paths_gnu
}

function uniformize_pootle_paths() {
	backup_db
	logt 1 "Uniformizing wrong pootle paths"
	fix_malformed_paths
}

function rescan_files() {
	logt 1 "Rescaning project files"
	start_pootle_session
	for (( i=0; i<${#PROJECT_NAMES[@]}; i++ ));  do
		project=${PROJECT_NAMES[$i]}
		logt 2 "$project"
		languages=`ls $PODIR/$project/`
		for language in $languages; do
			locale=$(get_locale_from_file_name $language)
			path=$(get_path $project $locale)
			logt 3 -n "$locale, posting to $path"
			curl -s -b "$PO_COOKIES" -c "$PO_COOKIES"  -d "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" -d "scan_files=Rescan project files"  "$PO_SRV$path/admin_files.html" > /dev/null
			check_command
		done
	done
	close_pootle_session
}

## RENAME PROJECT FUNCTIONS

function rename_pootle_store_store_entries() {
	logt 3 "Updating pootle_store_store table"
	currentName="$1"
	newName="$2"
	entries="$(get_pootle_store_store_entries $currentName)"
	done=false;
	until $done; do
		read line || done=true
		regex="($currentName/[^\,]+),(.+)"
		[[ "$line" =~ $regex ]] && file="${BASH_REMATCH[1]}" && pootlePath="${BASH_REMATCH[2]}"
		newFile=$(echo $file | sed -r "s:$currentName(.*):$newName\1:")
		newPootlePath=$(echo $pootlePath | sed -r "s:(.*)$currentName(.*):\1$newName\2:")
		sql="update pootle_store_store set file=\"$newFile\", pootle_path=\"$newPootlePath\" where file=\"$file\";"
		logt 4 -n "$sql"
		$MYSQL_COMMAND $DB_NAME -e "$sql" > /dev/null 2>&1
		check_command
	#logt 4 "Current file=$file, pootle_path=$pootlePath"
	#logt 4 "New     file=$newFile, pootle_path=$newPootlePath"
	done <<< "$entries"
}

function rename_pootle_app_directory_entries() {
	logt 3 "Updating pootle_app_directory table"
	currentName="$1"
	newName="$2"
	entries="$(get_pootle_app_directory_entries $currentName)"
	done=false;
	until $done; do
		read line || done=true
		regex="$currentName,(.+)"
		[[ "$line" =~ $regex ]] && pootlePath="${BASH_REMATCH[1]}"
		newPootlePath=$(echo $pootlePath | sed -r "s:(.*)$currentName(.*):\1$newName\2:")
		sql="update pootle_app_directory set name=\"$newName\", pootle_path=\"$newPootlePath\" where pootle_path=\"$pootlePath\";"
		logt 4 -n "$sql"
		$MYSQL_COMMAND $DB_NAME -e "$sql" > /dev/null 2>&1
		check_command
	#logt 4 "Current file=$currentName, pootle_path=$pootlePath"
	#logt 4 "New     file=$newName, pootle_path=$newPootlePath"
	done <<< "$entries"
}


function rename_pootle_app_translationproject_entries() {
	logt 3 "Updating pootle_app_translationproject table"
	currentName="$1"
	newName="$2"
	entries="$(get_pootle_app_translationproject_entries $currentName)"
	done=false;
	until $done; do
		read line || done=true
		regex="$currentName,(.+)"
		[[ "$line" =~ $regex ]] && pootlePath="${BASH_REMATCH[1]}"
		newPootlePath=$(echo $pootlePath | sed -r "s:(.*)$currentName(.*):\1$newName\2:")
		sql="update pootle_app_translationproject set real_path=\"$newName\", pootle_path=\"$newPootlePath\" where pootle_path=\"$pootlePath\";"
		logt 4 -n "$sql"
		$MYSQL_COMMAND $DB_NAME -e "$sql" > /dev/null 2>&1
		check_command
	#logt 4 "Current file=$currentName, pootle_path=$pootlePath"
	#logt 4 "New     file=$newName, pootle_path=$newPootlePath"
	done <<< "$entries"
}

function rename_pootle_app_project_entries() {
	logt 3 "Updating pootle_app_project table"
	currentName="$1"
	newName="$2"
	sql="update pootle_app_project set code=\"$newName\" where code=\"$currentName\";"
	logt 4 -n "$sql"
	$MYSQL_COMMAND $DB_NAME -e "$sql" > /dev/null 2>&1
	check_command
}

function rename_pootle_notifications_notice_entries() {
	logt 3 "Updating pootle_notifications_notice table"
	currentName="$1"
	newName="$2"
	entries="$(get_pootle_notifications_notice_entries $currentName)"
	done=false;
	until $done; do
		read line || done=true
		origLine="$line"
		regex="$currentName"
		while :; do
			newLine=$(echo $line | sed -r "s:(.*)$currentName(.*):\1$newName\2:")
			if [[ "$newLine" == "$line" ]]; then
				break;
			else
				line="$newLine"
			fi
		done;
		sql="update pootle_notifications_notice set message='$newLine' where message='$origLine';"
		logt 4 -n "$sql"
		$MYSQL_COMMAND $DB_NAME -e "$sql" > /dev/null 2>&1
		check_command
	#logt 4 "Current line=$origLine"
	#logt 4 "New     line=$newLine"
	done <<< "$entries"
}

function is_pootle_server_up() {
	wget -q --delete-after $PO_SRV
}

function exists_project_in_pootle() {
	wget --spider "$PO_PROJECTS_URL/$1" 2>&1 | grep 200 > /dev/null
}

function rename_pootle_project() {
	currentName="$1"
	newName="$2"
	if [[ "$currentName" == "" || "$newName" == "" || "$currentName" == "$newName" ]]; then
		logt 1 "Unable to rename Pootle project \"$currentName\" to \"$newName\". Either names are equal or some of them is empty"
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