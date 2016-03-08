#!/bin/bash

function clean_tables() {
	logt 3 "Cleaning DB tables";
	drop_table_sentences=$($MYSQL_DUMP_COMMAND $DB_NAME --add-drop-table --no-data | grep "^DROP")
	done=false;
	until $done; do
		read drop_table || done=true
		if [[ "$drop_table" != "" ]]; then
			logt 4 -n "$drop_table"
			$MYSQL_COMMAND $DB_NAME -s -e "$drop_table" > /dev/null 2>&1
			check_command
		fi;
	done <<< "$drop_table_sentences";
}

# given the storeId and the language key (unitId) returns the index of that translation unit in the DB
function get_index() {
	local i=$($MYSQL_COMMAND $DB_NAME -s  -e "select pootle_store_unit.index from pootle_store_unit where store_id=\"$1\" and unitid=\"$2\";"  | cut -d : -f2)
	echo $i;
}

# given the storeId and the language key (unitId) returns the id (pk)  of the translation unit in the DB
function get_unitid() {
	local i=$($MYSQL_COMMAND $DB_NAME -s  -e "select pootle_store_unit.id from pootle_store_unit where store_id=\"$1\" and unitid=\"$2\";"  | cut -d : -f2)
	echo $i;
}

# given the storeId and the language key (unitId) returns the source_f field of that translation unit in the DB, which stores the default (English) translation of the key
function get_sourcef() {
	local i=$($MYSQL_COMMAND $DB_NAME -s  -e "select pootle_store_unit.source_f from pootle_store_unit where store_id=\"$1\" and unitid=\"$2\";"  | cut -d : -f2)
	echo $i;
}

# given the storeId and the language key (unitId) returns the target_f field of that translation unit in the DB, which stores the translation of the key
function get_targetf() {
	local i=$($MYSQL_COMMAND $DB_NAME -s  -e "select pootle_store_unit.target_f from pootle_store_unit where store_id=\"$1\" and unitid=\"$2\";"  | cut -d : -f2)
	echo $i;
}

function count_targets() {
	local i=$(MYSQL_COMMAND $DB_NAME -s -e "set names utf8; select count(*) from pootle_store_unit where store_id=\"$1\";" | cut -d : -f2)
	echo $i
}

function export_targets() {
	$MYSQL_COMMAND $DB_NAME -s -e "set names utf8; select concat(unitid,\"=\",target_f) from pootle_store_unit where store_id=\"$1\" order by pootle_store_unit.index;" > $2
}

function export_template() {
	$MYSQL_COMMAND $DB_NAME -s -e "set names utf8; select concat(unitid,\"=\",source_f) from pootle_store_unit where store_id=\"$1\" order by pootle_store_unit.index;" > $2
}

## todo: http://cloud-10-50-0-102:443/pootle/ar/nuevo2/Language_ar.properties/translate/?unit=1014367
## todo: export only templates in regenerate-stores
## todo: check some translations for which publication failed
function transfer_store() {
	#transfer_store "$project" "$target_project_code" "$locale"
	source_project="$1"
	target_project="$2"
	locale="$3"

	source_storeId=$(get_store_id $source_project $locale)
	target_storeId=$(get_store_id $target_project $locale)

	logt 4 "Transferring translations from store $source_storeId ($source_project - $locale) to $target_storeId ($target_project - $locale)"

	key="$2"
	value="$3"


		index=$(get_index $storeId $key)
		id=$(get_unitid $storeId $key)
		sourcef=$(get_sourcef $storeId $key)
		#function dump_store() {
			#project="$1";
			#locale="$2";
			#langFile="$3";
			#storeId=$(get_store_id $project $locale)
			#logt 4 "Dumping store id $storeId into $langFile"
			#export_targets "$storeId" "$langFile"
		#}
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

# given a project name and a locale, returns the path for translations of that project in that language
# this is required to rescan files
function get_path() {
	project="$1"
	locale="$2"
	# value example: "/pt_BR/portal"
	local i="/$locale/$project/"
	echo $i;
}

# given the project name and a locale, returns the storeId of the store which has all translations of that project in that language
function get_store_id() {
	project="$1"
	locale="$2"
	local i=$($MYSQL_COMMAND $DB_NAME -s -e "select pootle_store_store.id from pootle_store_store where pootle_path=\"$(get_pootle_path $project $locale)\";"  | cut -d : -f2)
	echo $i;
}

function get_pootle_store_store_entries() {
	project="$1"
	local i=$($MYSQL_COMMAND $DB_NAME -s -e "select CONCAT(file,',',pootle_path) from pootle_store_store  where pootle_path like '%${project}%';")
	echo -e "$i";
}

function get_pootle_app_directory_entries() {
	project="$1"
	local i=$($MYSQL_COMMAND $DB_NAME -s -e "select CONCAT(name,',',pootle_path) from pootle_app_directory where name='${project}';")
	echo -e "$i";
}

function get_pootle_app_translationproject_entries() {
	project="$1"
	local i=$($MYSQL_COMMAND $DB_NAME -s -e "select CONCAT(real_path,',',pootle_path) from pootle_app_translationproject where real_path='${project}';")
	echo -e "$i";
}

function get_pootle_notifications_notice_entries() {
	project="$1"
	local i=$($MYSQL_COMMAND $DB_NAME -s -e "select message from pootle_notifications_notice where message like '%${project}%';")
	echo -e "$i";
}

function get_pootle_project_id_from_code() {
	project="$1"
	local i=$($MYSQL_COMMAND $DB_NAME -s -e "select id from pootle_app_project where code='${project}';")
	echo -e "$i";
}

function get_pootle_project_fullname_from_code() {
	project="$1"
	local i=$($MYSQL_COMMAND $DB_NAME -s -e "select fullname from pootle_app_project where code='${project}';")
	echo -e "$i";
}

function get_pootle_project_codes() {
	local i=$($MYSQL_COMMAND $DB_NAME -s -N -e "select code from pootle_app_project;")
	echo -e "$i";
}

function get_default_project_locales() {
	local i=$($MYSQL_COMMAND $DB_NAME -s -N -e "select code from pootle_app_language where id in (select language_id from pootle_app_translationproject where real_path='${PORTAL_PROJECT_ID}');")
	echo -e "$i" | grep -v "templates";
}

