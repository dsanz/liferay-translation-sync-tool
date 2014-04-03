#!/bin/bash

# this API allows to workaround a pootle bug so that new translations coming from a Language_*.properties file
# can be incorporated to the Pootle Database. This feature is used both from the pootle_manager (to post
# new tranlsations coming from source branches) and from the stand-alone version.

# common, base function for uploading a submission through pootle webui.
# It just checks if value is not auto-translated / auto-copied before publishing
# used from pootle manager as well as from the stand-alone version

# uploads a translation for a key in an specific project/language pair.
# storeId and path are pootle internal variables used to locate the project and language
# value is the actual translation for the given key.
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

# this uploads all submissions from a given file, computed from a project/locale pair.
function upload_submissions() {
	locale="$2"
	project="$1"
	storeId=$(get_store_id $project $locale)
	path=$(get_pootle_path $project $locale)
	filename=$(get_filename $locale)

    logt 3 "Posting the set of translations"

    checkTpl=false;
    if $3; then
        logt 4 "Checking existence of template file"
        templateName=$FILE.$PROP_EXT
        if [ -f $templateName ]; then
            read_locale_file $templateName "tpl"
            checkTpl=true;
            logt 4 "I'll use $templateName to detect untranslated strings and avoid posting them"
        fi;
    fi;

	done=false;
	until $done; do
	    read line || done=true
	    if is_key_line "$line" ; then
		    [[ "$line" =~ $kv_rexp ]] && key="${BASH_REMATCH[1]}" && value="${BASH_REMATCH[2]}"
            if [ ! checkTpl ]; then
			    upload_submission "$key" "$value" "$storeId" "$path"
			elif [[ ${T["tpl$key"]} != $value ]]; then
			    upload_submission "$key" "$value" "$storeId" "$path"
			else
			    logt 4 "Skipping untranslated key '$key': $value"
			fi
		fi
	done < $filename
}

# posts a file, including opening/closing session in pootle.
# intended to be called from the stand-alone version
function post_file() {
	project="$1"
	locale="$2"
	logt 2 "Posting '$locale' translations for $project"
	start_pootle_session
	upload_submissions "$1" "$2" true
	close_pootle_session
}

# posts a file without opening/closing session in pootle. Useful for posting a bunch of files.
# intended to be called from pootle-manager to upload new translations submitted to liferay code
function post_file_batch() {
	project="$1"
	locale="$2"
	logt 2 "Posting '$locale' translations for project $1"
	upload_submissions "$project" "$locale"
}