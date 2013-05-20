#!/bin/bash

####
## Pootle server communication
####

. api/api-base.sh
. to-pootle_file_poster.sh

# to Pootle

function update_pootle_db() {
	echo_cyan "[`date`] Updating pootle database..."
	for (( i=0; i<${#PROJECT_NAMES[@]}; i++ ));
	do
		project=${PROJECT_NAMES[$i]}
		src_dir=${PROJECT_SRC[$i]}
		echo_white "  $project: "
		echo_yellow "    Updating the set of translatable keys"
		echo -n "      Copying project files "
		cp "$src_dir/${FILE}.$PROP_EXT" "$PODIR/$project"
		check_command
		# Update database as well as file system to reflect the latest version of translation templates
		echo -n "      Updating Pootle templates "
		$POOTLEDIR/manage.py update_from_templates --project="$project" -v 0 > /dev/null 2>&1
		check_command
	done
}

function prepare_input_dirs() {
	echo_cyan "[`date`] Preparing project input working dirs..."
	for (( i=0; i<${#PROJECT_NAMES[@]}; i++ ));
	do
		project=${PROJECT_NAMES[$i]}
		echo_white "  $project: cleaning input working dirs"
		clean_dir "$TMP_PROP_IN_DIR/$project"
	done
}

function create_working_branch() {
	path="$1"
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
	path="$1"
	echo -n "      git checkout master "
	cd $path
	git checkout master > /dev/null 2>&1
	check_command
	echo -n "      git pull upstream master "
	git pull upstream master > /dev/null 2>&1
	check_command
}

function rotate_working_branch() {
	path="$1"
	cd $path
	git checkout master > /dev/null 2>&1
	# check if old branch exists
	if exists_branch $LAST_BRANCH $path; then
		echo -n "      git branch -D $LAST_BRANCH "
		git branch -D $LAST_BRANCH > /dev/null 2>&1
		check_command
	else
		echo "      branch '$LAST_BRANCH' does not exist, will be created now"
	fi;
	echo -n "      git branch -m $WORKING_BRANCH $LAST_BRANCH "
	git branch -m $WORKING_BRANCH $LAST_BRANCH > /dev/null 2>&1
	check_command
	echo "      Contents in '$LAST_BRANCH' will be used as reference of last successful Pootle update"
}

function setup_working_branches() {
	echo_cyan "[`date`] Setting up git branches for project(s)"
	old_dir=$pwd;
	for (( i=0; i<${#PATH_PROJECTS[@]}; i++ ));
	do
		projects=${PATH_PROJECTS[$i]}
		path=${PATH_BASE_DIR[$i]}
		echo_white  "  $path"
		echo_yellow "    for projects:$projects"
		pull_changes "$path";
		create_working_branch "$path"
	done;
	cd $old_dir
}

function rotate_working_branches() {
	echo_cyan "[`date`] Rotating git branches for project(s)"
	old_dir=$pwd;
	for (( i=0; i<${#PATH_PROJECTS[@]}; i++ ));
	do
		projects=${PATH_PROJECTS[$i]}
		path=${PATH_BASE_DIR[$i]}
		echo_white  "  $path"
		echo_yellow "    for projects:$projects"
 		rotate_working_branch "$path"
	done;
	cd $old_dir
}

function generate_addition() {
	path="$1"
	project="$2"
	cd $path
	files="$(ls ${FILE}${LANG_SEP}*.${PROP_EXT})"
	for file in $files; do
		if [[ "$file" != "${FILE}${LANG_SEP}en.${PROP_EXT}" ]]; then
			git diff $LAST_BRANCH $file | sed -r 's/^[^\(]+\(Automatic [^\)]+\)$//' | grep -E "^\+[^=+][^=]*" | sed 's/^+//g' > $TMP_PROP_IN_DIR/$project/$file
			number_of_additions=$(cat "$TMP_PROP_IN_DIR/$project/$file" | wc -l)
			if [[ $number_of_additions -eq 0 ]]; then
				rm "$TMP_PROP_IN_DIR/$project/$file"
			else
				echo -n "      ${file}: $number_of_additions key(s) added "
				check_command
			fi;
		fi
	done;
}

function generate_additions() {
	echo_cyan "[`date`] Calculating commited translations from last update"
	old_dir=$pwd;
	for (( i=0; i<${#PATH_BASE_DIR[@]}; i++ ));
	do
		projects=${PATH_PROJECTS[$i]}
		base_src_dir=${PATH_BASE_DIR[$i]}
		cd $base_src_dir
		echo_white  "  $base_src_dir"
		if exists_branch $LAST_BRANCH $base_src_dir; then
			git checkout $WORKING_BRANCH > /dev/null 2>&1
			for project in $projects; do
				echo_yellow "    '$project'"
				path=$(get_project_language_path "$project")
	 			generate_addition "$path" "$project"
			done;
		else
			echo "      There is no '$LAST_BRANCH' branch, so I can't diff it with '$WORKING_BRANCH' to detect additions for projects $projects"
		fi;
	done;
	cd $old_dir
}

function post_new_translations() {
	echo_cyan "[`date`] Posting commited translations from last update"
	old_dir=$pwd;
	echo_white  "  Creating session in Pootle"
	start_pootle_session
	for project in $(ls $TMP_PROP_IN_DIR); do
		echo_white  "  $project"
		cd $TMP_PROP_IN_DIR/$project
		for file in $(ls $TMP_PROP_IN_DIR/$project); do
			locale=$(echo $file | sed -r 's/Language_([^\.]+)\.properties/\1/')
			post_file_batch "$project" "$locale"
		done;
	done;
	echo_white  "  Closing session in Pootle"
	close_pootle_session
	cd $old_dir
}

function post_language_translations() {
	generate_additions
	post_new_translations
}