#!/bin/bash

function list_backups() {
	logt 1 "Available backups"

	for month in $(ls $TMP_DB_BACKUP_DIR/); do
		logt 2 "From $month"
		for backup_id in $(ls $TMP_DB_BACKUP_DIR/$month); do
			logt 3 "Backup ID: $backup_id"
			for backup_file in $(ls $TMP_DB_BACKUP_DIR/$month/$backup_id); do
				logt 4 "$(ls $TMP_DB_BACKUP_DIR/$month/$backup_id/$backup_file -lag)"
			done;
		done;
	done;
}

function backup_db() {
	if [[ "${DO_BACKUPS}x" != "1x" ]]; then
		logt 1 "Not creating backup. Please set DO_BACKUPS env variable to \"1\" to do them."
		return;
	fi;

	logt 1  "Backing up pootle data..."
	base_dir=$(date +%Y-%m);
	backup_dir=$(date +%F_%H-%M-%S)
	dumpfilename="pootle.sql"
	dumpfilepath="$TMP_DB_BACKUP_DIR/$base_dir/$backup_dir/$dumpfilename";
	fsfilename="po.tgz"
	fsfilepath="$TMP_DB_BACKUP_DIR/$base_dir/$backup_dir/$fsfilename";
	check_dir "$TMP_DB_BACKUP_DIR/$base_dir/$backup_dir"

	logt 2 "Dumping Pootle DB into $dumpfilepath"
	logt 3 -n "Running dump command ";
	$MYSQL_DUMP_COMMAND $DB_NAME > $dumpfilepath;
	check_command;

	logt 3 -n "Compressing db dump";
	bzip2 $dumpfilepath > /dev/null 2>&1;
	check_command;

	logt 2 "Compressing po/ dir into $fsfilepath"
	logt 3 -n "Running tar command: tar czvf $fsfilepath $PODIR";
	old_pwd=$(pwd)
	cd $PODIR
	tar czvf $fsfilepath * > /dev/null 2>&1;
	cd $old_pwd
	check_command;

	logt 2 "Backup ID: $backup_dir"
}

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

function export_targets() {
	$MYSQL_COMMAND $DB_NAME -s -e "set names utf8; select concat(unitid,\"=\",target_f) from pootle_store_unit where store_id=\"$1\";" > $2
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

