#!/bin/bash

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

function uniformize_pootle_paths() {
	backup_db
	logt 1 "Uniformizing wrong pootle paths"
	fix_malformed_paths_having_dashes
	fix_malformed_paths_gnu

}

function rescan_files() {
	logt 1 "Rescaning project files"
	start_pootle_session
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		logt 2 "$project"
		languages=`ls $PODIR/$project/`
		for language in $languages; do
			locale=$(get_locale_from_file_name $language)
			path=$(get_path $project $locale)
			logt 3 -n "$locale, posting to $path"
			curl $CURL_OPTS -d "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" -d "scan_files=Rescan project files"  "$PO_SRV$path/admin_files.html"
			check_command
		done
	done
	close_pootle_session
}
