#!/bin/bash

function upload_submission() {
	key="$1"
	value="$2"
	storeId="$3"
	path="$4"
	index=$(get_index $storeId $key)
	id=$(get_unitid $storeId $key)
	sourcef=$(get_sourcef $storeId $key)
	logt 4 -n "publishing translation '$key'"
	curl -s -b "$PO_COOKIES" -c "$PO_COOKIES"  -d "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" -d "id=$id" -d "path=$path" -d  "pootle_path=$path" -d "source_f_0=$sourcef" -d  "store=$path" -d "submit=Submit" -d  "target_f_0=$value" -d "index=$index" "$PO_SRV$path/translate/?" > /dev/null
	check_command
}

function upload_submissions() {
	locale="$2"
	project="$1"
	storeId=$(get_store_id $project $locale)
	path=$(get_pootle_path $project $locale)
	filename=$(get_filename $locale)

	while read line; do
		key=$(echo $line | sed s/=.*//)
		value=$(echo $line | sed -r s/^[^=]+=//)
		upload_submission "$key" "$value" "$storeId" "$path"
	done < $filename
}

# posts a file, including opening/closing session in pootle.
function post_file() {
	project="$1"
	locale="$2"
	logt 2 "Posting new '$locale' translations for $project"
	start_pootle_session
	upload_submissions "$1" "$2"
	close_pootle_session
}

# posts a file without opening/closing session in pootle. Useful for posting a bunch of files
function post_file_batch() {
	project="$1"
	locale="$2"
	logt 2 "Posting new '$locale' translations for $project"
	upload_submissions "$project" "$locale"
}