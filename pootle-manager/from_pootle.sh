#!/bin/bash

. common_functions.sh

####
## Pootle server communication
####


# from pootle

function update_pootle_files() {
	echo_cyan "[`date`] Updating pootle files from pootle DB..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		echo_white "  $project: synchronizing stores"
		# Save all translations currently in database to the file system
		$POOTLEDIR/manage.py sync_stores --project="$project" -v 0
	done
}

function reformat_pootle_files() {
	echo_cyan "[`date`] Reformatting exported pootle files..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		languages=`ls $PODIR/$project`
		echo_white "  $project: reformatting files"
		clean_dir "$TMP_PROP_OUT_DIR/$project"
		for language in $languages; do
			if [ "$language" != "$FILE.$PROP_EXT" ]; then
				echo "    $project/$language "
				lang=`echo $language  | cut -f2- -d _ | cut -f1 -d .`
				echo "    prop -> po $project/$language"
				prop2po -i "$PODIR/$project/$language" -o "$TMP_PO_DIR/$project/" -t "$PODIR/$project/$FILE.$PROP_EXT"
				check_command
				echo "    po -> prop $project/$language"
				po2prop -i "$TMP_PO_DIR/$project/${FILE}_$lang.$PO_EXT" -o "$TMP_PROP_OUT_DIR/$project/" -t "$PODIR/$project/$FILE.$PROP_EXT"
				check_command
			fi
		done
	    cp -f "$PODIR/$project/$FILE.$PROP_EXT" "$TMP_PROP_OUT_DIR/$project/"
	done
}

function add_untranslated() {
	echo_cyan "[`date`] Adding automatic translations to untranslated entries..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		languages=`ls $PODIR/$project`
		[ ! -d "$TMP_PROP_OUT_DIR/$project" ] && mkdir -p "$TMP_PROP_OUT_DIR/$project"
		echo_white "  $project: refilling untranslated entries"
		for language in $languages; do
			refill_automatic_prop $project $language
		done
	done
}

function prepare_vcs() {
	echo_cyan "[`date`] Preparing processed files to VCS dir for commit..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		languages=`ls $PODIR/$project`
		echo_white "  $project: processing files"
		for language in $languages; do
			if [ "$FILE.$PROP_EXT" != "$language" ] ; then
				echo -n "    $project/$language: "
				if [ "`diff $TMP_PROP_OUT_DIR/$project/$language $TMP_PROP_IN_DIR/$project/svn/$language`" != "" ]; then
					echo  "   * $SVNDIR/$project/$language"
					cp -f "$TMP_PROP_OUT_DIR/$project/$language" "$SVNDIR/$project/$language"
				fi
			fi
		done
	done
}

function prepare_output_dirs() {
	echo_cyan "[`date`] Preparing project output working dirs..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		echo_white "  $project: creating / cleaing dirs"
		clean_dir "$TMP_PROP_OUT_DIR/$project"
		clean_dir "$TMP_PO_DIR/$project"
	done
}

function backup_db() {
	echo_cyan "[`date`] Backing up Pootle DB..."
	dirname=$(date +%Y-%m);
	filename=$(echo $(date +%F_%H-%M-%S)"-pootle.sql");
	dumpfile="$TMP_DB_BACKUP_DIR/$dirname/$filename";

	echo_white "  Dumping Pootle DB into $dumpfile"
	check_dir "$TMP_DB_BACKUP_DIR/$dirname"
	echo -n  "    Running dump command ";
	$DB_DUMP_COMMAND > $dumpfile;
	check_command;
}