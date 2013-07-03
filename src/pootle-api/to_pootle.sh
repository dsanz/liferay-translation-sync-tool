#!/bin/bash

. api/api-base.sh
. pootle-api/to_pootle-file_poster.sh

function update_pootle_db() {
	logt 1 "Updating pootle database..."
	for (( i=0; i<${#PROJECT_NAMES[@]}; i++ ));
	do
		project=${PROJECT_NAMES[$i]}
		src_dir=${PROJECT_SRC[$i]}
		logt 2 "$project: "
		logt 3 "Updating the set of translatable keys"
		logt 4 -n "Copying project files "
		cp "$src_dir/${FILE}.$PROP_EXT" "$PODIR/$project"
		check_command
		# Update database as well as file system to reflect the latest version of translation templates
		logt 4 -n "Updating Pootle templates (this may take a while...)"
		$POOTLEDIR/manage.py update_from_templates --project="$project" -v 0 > /dev/null 2>&1
		check_command
	done
}

function prepare_input_dirs() {
	logt 1 "Preparing project input working dirs..."
	for (( i=0; i<${#PROJECT_NAMES[@]}; i++ ));
	do
		project=${PROJECT_NAMES[$i]}
		logt 2 "$project: cleaning input working dirs"
		clean_dir "$TMP_PROP_IN_DIR/$project"
	done
}

function create_working_branch() {
	path="$1"
	cd $path
	if exists_branch $WORKING_BRANCH $path; then
		logt 4 -n "'$WORKING_BRANCH' branch already exists. There seems to be a previous, interrupted process. Deleting branch '$WORKING_BRANCH' "
		git branch -D $WORKING_BRANCH > /dev/null 2>&1
		check_command
	fi;
	logt 4 -n "git checkout -b $WORKING_BRANCH "
	git checkout -b $WORKING_BRANCH > /dev/null 2>&1
	check_command
}

function rotate_working_branch() {
	path="$1"
	cd $path
	git checkout master > /dev/null 2>&1
	# check if old branch exists
	if exists_branch $LAST_BRANCH $path; then
		logt 4 -n "git branch -D $LAST_BRANCH "
		git branch -D $LAST_BRANCH > /dev/null 2>&1
		check_command
	else
		logt 4 "branch '$LAST_BRANCH' does not exist, will be created now"
	fi;
	logt 4 -n "git branch -m $WORKING_BRANCH $LAST_BRANCH "
	git branch -m $WORKING_BRANCH $LAST_BRANCH > /dev/null 2>&1
	check_command
	logt 4 "Contents in '$LAST_BRANCH' will be used as reference of last successful Pootle update"
}

function setup_working_branches() {
	logt 1 "Setting up git branches for project(s)"
	old_dir=$pwd;
	for (( i=0; i<${#PATH_PROJECTS[@]}; i++ ));
	do
		projects=${PATH_PROJECTS[$i]}
		path=${PATH_BASE_DIR[$i]}
		logt 2 "$path"
		logt 3 "for projects:$projects"
		goto_master "$path";
		create_working_branch "$path"
	done;
	cd $old_dir
}

function rotate_working_branches() {
	logt 1 "Rotating git branches for project(s)"
	old_dir=$pwd;
	for (( i=0; i<${#PATH_PROJECTS[@]}; i++ ));
	do
		projects=${PATH_PROJECTS[$i]}
		path=${PATH_BASE_DIR[$i]}
		logt 2 "$path"
		logt 3 "for projects:$projects"
 		rotate_working_branch "$path"
	done;
	cd $old_dir
}

function generate_addition() {
	path="$1"
	project="$2"
	cd $path > /dev/null 2>&1
	files="$(ls ${FILE}${LANG_SEP}*.${PROP_EXT} 2>/dev/null)"
	for file in $files; do
		if [[ "$file" != "${FILE}${LANG_SEP}en.${PROP_EXT}" ]]; then
			git diff $LAST_BRANCH $file | sed -r 's/^[^\(]+\(Automatic [^\)]+\)$//' | grep -E "^\+[^=+][^=]*" | sed 's/^+//g' > $TMP_PROP_IN_DIR/$project/$file
			number_of_additions=$(cat "$TMP_PROP_IN_DIR/$project/$file" | wc -l)
			color="$WHITE"
			if [[ $number_of_additions -eq 0 ]]; then
				rm "$TMP_PROP_IN_DIR/$project/$file"
				color="$COLOROFF"
			fi;
			loglc 0 "$color" -n $(get_locale_from_file_name $file)"($number_of_additions) "
		fi
	done;
	log ""
}

function generate_additions() {
	logt 1 "Calculating committed translations from last update"
	old_dir=$pwd;
	for (( i=0; i<${#PATH_BASE_DIR[@]}; i++ ));
	do
		projects=${PATH_PROJECTS[$i]}
		base_src_dir=${PATH_BASE_DIR[$i]}
		cd $base_src_dir
		logt 2 "$base_src_dir"
		if exists_branch $LAST_BRANCH $base_src_dir; then
			git checkout $WORKING_BRANCH > /dev/null 2>&1
			for project in $projects; do
				logt 3 "$project"
				path=$(get_project_language_path "$project")
	 			generate_addition "$path" "$project"
			done;
		else
			logt 3 "There is no '$LAST_BRANCH' branch, so I can't diff it with '$WORKING_BRANCH' to detect additions for projects $projects"
		fi;
	done;
	cd $old_dir
}

function post_new_translations() {
	logt 1 "Posting commited translations from last update"
	old_dir=$pwd;
	logt 2 "Creating session in Pootle"
	start_pootle_session
	for project in $(ls $TMP_PROP_IN_DIR); do
		logt 2 "Uploading translations for project $project"
		cd $TMP_PROP_IN_DIR/$project > /dev/null 2>&1
		files="$(ls ${FILE}${LANG_SEP}*.${PROP_EXT} 2>/dev/null)"
		for file in $files; do
			locale=$(get_locale_from_file_name $file)
			post_file_batch "$project" "$locale"
		done;
	done;
	logt 2 "Closing session in Pootle"
	close_pootle_session
	cd $old_dir
}

function post_language_translations() {
	generate_additions
	post_new_translations
}
