#!/bin/bash

. api/api-base.sh
. pootle-api/to_pootle-file_poster.sh

function update_pootle_db() {
	logt 1 "Updating pootle database..."
	for project in "${!PROJECT_NAMES[@]}"; do
		src_dir=${PROJECT_SRC_LANG_BASE["$project"]}
		logt 2 "$project: "
		logt 3 "Updating the set of translatable keys"
		logt 4 -n "Copying project files "
		cp "$src_dir/${FILE}.$PROP_EXT" "$PODIR/$project"
		check_command
		# Update database as well as file system to reflect the latest version of translation templates
		logt 4 "Updating Pootle templates (this may take a while...)"
		call_manage "update_from_templates" "--project=$project" "-v 0"
	done
}

function prepare_input_dirs() {
	logt 1 "Preparing project input working dirs..."
	logt 2 "Cleaning general input working dir"
	clean_dir "$TMP_PROP_IN_DIR/"
	for project in "${!PROJECT_NAMES[@]}"; do
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

function setup_working_branches() {
	logt 1 "Setting up git branches for project(s)"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		projects="${PROJECTS_BY_GIT_ROOT[$"git_root"]}"
		logt 2 "$base_src_dir"
		logt 3 "for projects:$projects"
		goto_master "$base_src_dir";
		create_working_branch "$base_src_dir"
	done;
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

function create_branch_at_child_of_last_export_commit() {
	# assume we are now in master
	base_src_dir="$1"
	logt 3 "Creating branch at child of last export commit"
	logt 4 "Searching git history for last export commit"
	cd $base_src_dir
	child_of_last_export="HEAD"
	last_export_commit=$(git log -n 1 --grep "$product_name" --after 2012 --format=format:"%H")
	if [[ $last_export_commit == "" ]]; then
		logt 5 "I couldn't find a previous export commit containing $product_name"
		last_export_commit=$(git log -n 1 --grep "$old_product_name" --after 2012 --format=format:"%H")
	fi;
	if [[ $last_export_commit == "" ]]; then
		logt 5 "I couldn't find a previous export commit containing $old_product_name"
	else
		child_of_last_export=$(git rev-list --children --after 2012 HEAD | grep "^$last_export_commit" | cut -f 2 -d ' ')
	fi;
	last_export_msg=$(git show --pretty=oneline --abbrev-commit ${child_of_last_export}^ | head -n 1)
	logt 4 "Using $child_of_last_export as reference (parent commit is: $last_export_msg)"
	logt 4 "Setting up $LAST_BRANCH branch pointing to $child_of_last_export"
	if exists_branch $LAST_BRANCH $base_src_dir; then
		logt 5 -n "git branch -D $LAST_BRANCH";
		git branch -D $LAST_BRANCH  > /dev/null 2>&1
		check_command
	fi;
	logt 5 -n "git branch $LAST_BRANCH $child_of_last_export";
	git branch $LAST_BRANCH $child_of_last_export
	check_command
}

function generate_additions() {
	logt 1 "Calculating committed translations from last export commit"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		projects="${PROJECTS_BY_GIT_ROOT["$base_src_dir"]}"
		cd $base_src_dir
		logt 2 "$base_src_dir"
		create_branch_at_child_of_last_export_commit "$base_src_dir"
		if exists_branch $LAST_BRANCH $base_src_dir; then
			git checkout $WORKING_BRANCH > /dev/null 2>&1
			for project in $projects; do
				logt 3 "$project"
				path="${PROJECT_SRC_LANG_BASE["$project"]}"
				generate_addition "$path" "$project"
			done;
		else
			logt 3 "There is no '$LAST_BRANCH' branch, so I can't diff it with '$WORKING_BRANCH' to detect additions for projects $projects"
		fi;
	done;
}

function post_new_translations() {
	logt 1 "Posting commited translations from last update"
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
}

function post_language_translations() {
	generate_additions
	post_new_translations
}

# given a project and a language, reads the Language_xx.properties file
# present in current directory puts it into array T using the locale as prefix
function read_derived_language_file() {
	project="$1";
	locale="$2";
	langFile="$FILE$LANG_SEP$locale.$PROP_EXT"
	prefix=$(get_derived_language_prefix $project $locale)
	read_locale_file $langFile $prefix "$3"
}

function get_derived_language_prefix() {
	echo d$1$2
}

function post_derived_translations() {
	project="$1"
	derived_locale="$2"
	parent_locale="$3"

	prepare_output_dir $project
	logt 2 "Reading language files"
	logt 3 "Reading $derived_locale file"
	read_derived_language_file $project $derived_locale true
	logt 3 "Reading pootle store for parent language $parent_locale in project $project"
	read_pootle_store $project $parent_locale

	# TODO: try to read Language.properties to avoid uploading untranslated keys
	# best way to achieve this is calling upload_submissions with a filtered version of derived file
	storeId=$(get_store_id $project $derived_locale)
	path=$(get_pootle_path $project $derived_locale)

	logt 2 "Uploading..."
	start_pootle_session
	for key in "${K[@]}"; do
		valueDerived=${T["d$project$derived_locale$key"]}
		valueParent=${T["s$project$parent_locale$key"]}
		if [[ "$valueDerived" != "$valueParent" ]]; then
			upload_submission "$key" "$valueDerived" "$storeId" "$path"
		fi;
	done;
	close_pootle_session
}