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
	$DB_DUMP_COMMAND > $dumpfilepath;
	check_command;

    logt 2 "Compressing po/ dir into $fsfilepath"
	logt 3 -n "Running tar command: tar czvf $fsfilepath $PODIR";
	tar czvf $fsfilepath $PODIR > /dev/null 2>&1;
	check_command;
}

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

# given the storeId and the language key (unitId) returns the target_f field of that translation unit in the DB, which stores the translation of the key
function get_targetf() {
	local i=$(mysql $DB_NAME -s  -e "select pootle_store_unit.target_f from pootle_store_unit where store_id=\"$1\" and unitid=\"$2\";"  | cut -d : -f2)
	echo $i;
}

function export_targets() {
    mysql pootle -s -e "select concat(unitid,\"=\",target_f) from pootle_store_unit where store_id=\"$1\";" > $2
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
	local i=$(mysql $DB_NAME -s  -e "select pootle_store_store.id from pootle_store_store where pootle_path=\"$(get_pootle_path $project $locale)\";"  | cut -d : -f2)
	echo $i;
}


function fix_pootle_path() {
   path="$1"
   correctPath="$2"
   filePath="$3"
   correctFilePath="$4"
   correctFileName="$5"

   logt 3 -n "Updating (pootle_path,file,name) columns in 'pootle_store_store' database table.";
   mysql $DB_NAME -s -e "update pootle_store_store set pootle_path='$correctPath',file='$correctFilePath',name='$correctFileName' where pootle_path='$path'"; > /dev/null 2>&1
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
      #logt 4 -n "update_from_templates --project=$project --language=$locale $correctFileName"
      $POOTLEDIR/manage.py update_from_templates --project="$project" --language="$locale" -v 0 > /dev/null 2>&1
      check_command
   fi
}

function fix_malformed_paths_having_dashes() {
    malformedPathsHavingDashes=$(mysql $DB_NAME -s -e "select pootle_path from pootle_store_store where pootle_path like '%Language-%';" | grep properties)
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
    malformedPathsGnu=$(mysql $DB_NAME -s -e "select pootle_path  path from pootle_store_store where name not like 'Language%' and name not like '%.po';" | grep properties)
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

function fix_malformed_paths() {
    fix_malformed_paths_having_dashes
    fix_malformed_paths_gnu
}