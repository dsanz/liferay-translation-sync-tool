#!/bin/bash

function upload_submission() {
	key="$1"
	value="$2"
	storeId="$3"
	path="$4"

    if is_translated_value "$value"; then
	    logt 4 -n "publishing translation '$key': $value"
	    index=$(get_index $storeId $key)
	    id=$(get_unitid $storeId $key)
	    sourcef=$(get_sourcef $storeId $key)

	    #logt 4 -n "curl -s -b $PO_COOKIES -c $PO_COOKIES  -d csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7` -d id=$id -d path=$path -d pootle_path=$path -d source_f_0=$sourcef -d store=$path -d submit=Submit -d target_f_0=$value -d index=$index $PO_SRV$path/translate/?"
	    curl -s -b "$PO_COOKIES" -c "$PO_COOKIES"  -d "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" -d "id=$id" -d "path=$path" -d  "pootle_path=$path" -d "source_f_0=$sourcef" -d  "store=$path" -d "submit=Submit" -d  "target_f_0=$value" -d "index=$index" "$PO_SRV$path/translate/?" > /dev/null
	    check_command
	else
	    logt 4 "Skipping untranslated key '$key': $value"
	fi
}

function upload_submissions() {
	locale="$2"
	project="$1"
	storeId=$(get_store_id $project $locale)
	path=$(get_pootle_path $project $locale)
	filename=$(get_filename $locale)

	done=false;
	until $done; do
	    read line || done=true
	    if is_key_line "$line" ; then
		    [[ "$line" =~ $kv_rexp ]] && key="${BASH_REMATCH[1]}" && value="${BASH_REMATCH[2]}"
			upload_submission "$key" "$value" "$storeId" "$path"
		fi
	done < $filename
}

# posts a file, including opening/closing session in pootle.
function post_file() {
	project="$1"
	locale="$2"
	logt 3 "Posting '$locale' translations"
	start_pootle_session
	upload_submissions "$1" "$2"
	close_pootle_session
}

# posts a file without opening/closing session in pootle. Useful for posting a bunch of files
function post_file_batch() {
	project="$1"
	locale="$2"
	logt 3 "Posting '$locale' translations"
	upload_submissions "$project" "$locale"
}