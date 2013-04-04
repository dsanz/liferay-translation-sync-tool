#!/bin/bash

####
## Pootle server communication
####

. common-functions.sh

# to Pootle

function update_pootle_db() {
	echo_cyan "[`date`] Updating pootle database..."
	for project in "${!PROJECTS[@]}";
	do
		echo_white "  $project: "
		echo_yellow "    Updating the set of translatable keys"
		echo -n "      Copying project files "
		cp "${PROJECTS[$project]}/${FILE}.$PROP_EXT" "$PODIR/$project"
		check_command
		# Update database as well as file system to reflect the latest version of translation templates
		echo -n "      Updating Pootle templates "
		$POOTLEDIR/manage.py update_from_templates --project="$project" -v 0 > /dev/null 2>&1
		check_command
	done
}

function prepare_input_dirs() {
	echo_cyan "[`date`] Preparing project input working dirs..."
	for project in "${!PROJECTS[@]}";
	do
		echo_white "  $project: cleaning input working dirs"
		clean_dir "$TMP_PROP_IN_DIR/$project"
	done
}

function create_working_branch() {
	path="$1"

	echo "      creating working branch '$WORKING_BRANCH'"
	cd $path
	if exists_branch $WORKING_BRANCH $path; then
		echo -n "      '$WORKING_BRANCH' branch already exists. There seems to be a previous, interrupted process. Deleting branch '$WORKING_BRANCH' "
		git branch -D $WORKING_BRANCH > /dev/null 2>&1
		check_command
	fi;
	echo -n "      git checkout -b $WORKING_BRANCH "
	git checkout -b $WORKING_BRANCH > /dev/null 2>&1
	check_command
}

function pull_changes() {
	cd $1
	echo -n "      git checkout master "
	git checkout master > /dev/null 2>&1
	check_command
	echo -n "      git pull upstream master "
	git pull upstream master > /dev/null 2>&1
	check_command
}

function setup_working_branches() {
	echo_cyan "[`date`] Setting up git branches for project(s)"
	declare -A paths;
	for project in "${!PROJECTS[@]}";
	do
		src_dir=$(get_src_working_dir $project)
		paths[$src_dir]="${paths[$src_dir]} $project"
	done

	old_dir=$pwd;
	for path in "${!paths[@]}";
	do
		echo_white  "  $path"
		echo_yellow "    for projects:${paths[$path]}"
 		pull_changes $path;
 		create_working_branch $path
	done;
	cd $old_dir
}