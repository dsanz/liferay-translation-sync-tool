#!/bin/bash

# given the storeId and the language key (unitId) returns the index of that translation unit in the DB
function get_index() {
	local i=$(mysql $DB_NAME -s  -e "select pootle_store_unit.index from pootle_store_unit where store_id=\"$1\" and unitid=\"$2\";"  | cut -d : -f2)
	echo $i;
}

# given the storeId and the language key (unitId) returns the id (pk)  of the translation unit in the DB
function get_unitid() {
	local i=$(mysql $DB_NAME -s  -e "select pootle_store_unit.id from pootle_store_unit where store_id=\"$1\" and unitid=\"$2\";"  | cut -d : -f2)
	echo $i;
}

# given the storeId and the language key (unitId) returns the source_f field of that translation unit in the DB, which stores the default (English) translation of the key
function get_sourcef() {
	local i=$(mysql $DB_NAME -s  -e "select pootle_store_unit.source_f from pootle_store_unit where store_id=\"$1\" and unitid=\"$2\";"  | cut -d : -f2)
	echo $i;
}

# given a locale name such as "pt_BR" returns the file name "Language_pt_BR.properties"
function get_filename(){
	local i="Language_$1.properties"
	echo $i;
}

# given a project name and a locale, returns the path of the store for translations of that project in that language
# this path allows to query the table pootle_store_store by "pootle_path" and get the storeId
# it's also required for preparing the post (see upload_submission)
function get_pootle_path() {
	project="$1"
	locale="$2"
	# value example: "/pt_BR/portal/Language_pt_BR.properties"
	local i="/$locale/$project/$(get_filename $locale)"
	echo $i;
}

# given the project name and a locale, returns the storeId of the store which has all translations of that project in that language
function get_store_id() {
	project="$1"
	locale="$2"
	local i=$(mysql $DB_NAME -s  -e "select pootle_store_store.id from pootle_store_store where pootle_path=\"$(get_pootle_path $project $locale)\";"  | cut -d : -f2)
	echo $i;
}

function upload_submission() {
	key="$1"
	value="$2"
	storeId="$3"
	path="$4"
	index=$(get_index $storeId $key)
	id=$(get_unitid $storeId $key)
	sourcef=$(get_sourcef $storeId $key)
    echo "      posting translation for '$key'"
	curl -s -b "$PO_COOKIES" -c "$PO_COOKIES"  -d "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" -d "id=$id" -d "path=$path" -d  "pootle_path=$path" -d "source_f_0=$sourcef" -d  "store=$path" -d "submit=Submit" -d  "target_f_0=$value" -d "index=$index" "$PO_SRV$path/translate/?" > /dev/null
}

function post_file() {
	locale="$2"
	project="$1"
	storeId=$(get_store_id $project $locale)
	path=$(get_pootle_path $project $locale)
	filename=$(get_filename $locale)

	echo_yellow "    Posting new translations for $project "
	start_pootle_session
	while read line; do
		key=$(echo $line | sed s/=.*//)
		value=$(echo $line | sed -r s/^[^=]+=//)
		upload_submission "$key" "$value" "$storeId" "$path"
	done < $filename
	close_pootle_session
}


