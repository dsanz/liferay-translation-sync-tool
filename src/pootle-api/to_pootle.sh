#!/bin/bash

. api/api-base.sh
. pootle-api/to_pootle-file_poster.sh

function update_pootle_db_from_templates() {
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

function clean_temp_input_dirs() {
	logt 1 "Preparing project input working dirs..."
	logt 2 "Cleaning general input working dir"
	clean_dir "$TMP_PROP_IN_DIR/"
	for project in "${!PROJECT_NAMES[@]}"; do
		logt 2 "$project: cleaning input working dirs"
		clean_dir "$TMP_PROP_IN_DIR/$project"
	done
}

function generate_addition() {
	project="$1"
	path="$2"
	file="$3"
	commit="$4"

	cd $path > /dev/null 2>&1
	if [[ "$file" != "${FILE}${LANG_SEP}en.${PROP_EXT}" ]]; then
		logt 5 -n "Generating additions from: git diff $commit $file "
		git diff $commit $file | sed -r 's/^[^\(]+\(Automatic [^\)]+\)$//' | grep -E "^\+[^=+][^=]*" | sed 's/^+//g' > $TMP_PROP_IN_DIR/$project/$file
		number_of_additions=$(cat "$TMP_PROP_IN_DIR/$project/$file" | wc -l)
		color="$WHITE"
		if [[ $number_of_additions -eq 0 ]]; then
			rm "$TMP_PROP_IN_DIR/$project/$file"
			color="$COLOROFF"
		fi;
		loglc 0 "$color" -n $(get_locale_from_file_name $file)"($number_of_additions) "
	fi;
	log ""
}

function get_last_export_commit() {
	# assume we are now in master
	path="$1"
	file="$2"

	msg="$file: "
	cd $path
	child_of_last_export="HEAD"
	last_export_commit=$(git log -n 1 --grep "$product_name" --after 2012 --format=format:"%H" $file)
	if [[ $last_export_commit == "" ]]; then
		msg="$msg (no export commit containing $product_name) "
		last_export_commit=$(git log -n 1 --grep "$old_product_name" --after 2012 --format=format:"%H" $file)
	fi;
	if [[ $last_export_commit == "" ]]; then
		msg="$msg (no export commit containing $product_name) "
	else
		child_of_last_export=$(git rev-list --children --after 2012 HEAD | grep "^$last_export_commit" | cut -f 2 -d ' ')
	fi;
	msg="$msg using $child_of_last_export"
	logt 4 "$msg"
	echo "$child_of_last_export";
}

function generate_additions() {
	logt 1 "Calculating committed translations from latest export commit, for each project/language"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		projects="${PROJECTS_BY_GIT_ROOT["$base_src_dir"]}"
		cd $base_src_dir
		logt 2 "$base_src_dir"
		for project in $projects; do
			logt 3 "$project"
			path="${PROJECT_SRC_LANG_BASE["$project"]}"
			cd $path > /dev/null 2>&1
			for language_file in $(ls ${FILE}${LANG_SEP}*.$PROP_EXT 2>/dev/null); do
				commit=$(get_last_export_commit "$path" "$language_file")
				generate_addition "$project" "$path" "$language_file" "$commit"
			done
		done;
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