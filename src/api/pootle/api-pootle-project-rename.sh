#!/bin/bash

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
		newLine=$(echo $line | sed "s/$currentName/$newName/g")
		sql="update pootle_notifications_notice set message='$newLine' where message='$origLine';"
		logt 4 -n "$sql"
		$MYSQL_COMMAND $DB_NAME -e "$sql" > /dev/null 2>&1
		check_command
	#logt 4 "Current line=$origLine"
	#logt 4 "New     line=$newLine"
	done <<< "$entries"
}
