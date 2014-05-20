#!/bin/bash

function backup_db() {
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

function restore_backup() {
	backup_dir="$1"
	base_dir=$(echo "$backup_dir" | cut -d "-" -f 1-2)
	dumpfilename="pootle.sql"
	bzippeddumpfilename="pootle.sql.bz2"
	dumpfilepath="$TMP_DB_BACKUP_DIR/$base_dir/$backup_dir/$dumpfilename";
	bzippeddumpfilepath="$TMP_DB_BACKUP_DIR/$base_dir/$backup_dir/$bzippeddumpfilename";
	fsfilename="po.tgz"
	fsfilepath="$TMP_DB_BACKUP_DIR/$base_dir/$backup_dir/$fsfilename";

	if is_pootle_server_up; then
		logt 1 "Unable to restore backup as Pootle server is running. Please stop the server and rerun this action"
	elif [[ ! -f $bzippeddumpfilepath ]] || [[ ! -f $fsfilepath ]]; then
		logt 1 "Can't find backup files $bzippeddumpfilepath and/or $fsfilepath. Check backup ID $backup_dir"
	else
		logt 1  "Restoring pootle data from backup ID: $backup_dir"
		logt 2  "Restoring pootle database"
		logt 3 -n "Decompressing db dump";
		bunzip2 -k $bzippeddumpfilepath > /dev/null 2>&1;
		check_command;

		clean_tables
		logt 3 -n "Restoring DB dump";
		cat $dumpfilepath | $MYSQL_COMMAND $DB_NAME
		check_command;

		logt 2  "Restoring pootle filesystem"
		clean_dir $PODIR
		logt 3 -n "Decompressing filesystem backup"
		tar xf $fsfilepath -C $PODIR > /dev/null 2>&1;
		check_command;

		logt 2 "Cleaning files"
		rm $dumpfilepath;
	fi;
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