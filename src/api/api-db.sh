#!/bin/bash

function backup_db() {
	logt 1  "Backing up pootle data..."
	dirname=$(date +%Y-%m);
	filePrefix=$(date +%F_%H-%M-%S)
	dumpfilename="$filePrefix-pootle.sql"
	dumpfilepath="$TMP_DB_BACKUP_DIR/$dirname/$dumpfilename";
	fsfilename="$filePrefix-po.tgz"
	fsfilepath="$TMP_DB_BACKUP_DIR/$dirname/$fsfilename";
    check_dir "$TMP_DB_BACKUP_DIR/$dirname"

	logt 2 "Dumping Pootle DB into $dumpfilepath"
	logt 3 -n "Running dump command ";
	$MYSQL_DUMP_COMMAND $DB_NAME > $dumpfilepath;
	check_command;

	logt 3 -n "Compressing db dump";
	bzip2 $dumpfilepath > /dev/null 2>&1;
	check_command;

	logt 2 "Compressing po/ dir into $fsfilepath"
	logt 3 -n "Running tar command: tar czvf $fsfilepath $PODIR";
	tar czvf $fsfilepath $PODIR > /dev/null 2>&1;
	check_command;
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