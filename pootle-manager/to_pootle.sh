#!/bin/bash

####
## Pootle server communication
####

. common-functions.sh

# to Pootle

function update_pootle_db() {
	echo_cyan "[`date`] Updating pootle database..."
	rm -f "$PODIR/$project/*"
	projects=`ls $TMP_PROP_IN_DIR`
	for project in $projects;
	do
		echo_white "  $project: copying project files"
		cp "$TMP_PROP_IN_DIR/$project/svn/${FILE}.$PROP_EXT" "$PODIR/$project"
		# Update database as well as file system to reflect the latest version of translation templates
		echo_white "  $project: updating Pootle templates"
		$POOTLEDIR/manage.py update_from_templates --project="$project"	-v 0
	done
}

function prepare_input_dirs() {
	echo_cyan "[`date`] Preparing project input working dirs..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		echo_white "  $project: cleaning input working dirs"
		clean_dir "$TMP_PROP_IN_DIR/$project"
		clean_dir "$TMP_PROP_IN_DIR/$project/svn"
		clean_dir "$SVNDIR"
	done
}