## Pootle communication functions

function sync_stores() {
	project="$1"
	logt 2 "Synchronizing pootle stores for all languages ($project) "
	check_dir "$PODIR/$project"
	# Save all translations currently in database to the file system
	call_manage "sync_stores" "--project=$project" "-v 0" "--overwrite"
}

# tells pootle to export its translations to properties files to $PODIR dir
# and copies them to prop_out dirs for further processing
# (all projects)
function export_pootle_translations_to_temp_dirs() {
	logt 1 "Exporting pootle files from pootle DB into temp dirs..."
	read_pootle_projects_and_locales
	for project in "${POOTLE_PROJECT_CODES[@]}"; do
		export_pootle_project_translations_to_temp_dirs "$project"
	done
}

# tells pootle to export its translations to properties files to $PODIR dir
# and copies them to prop_out dirs for further processing
# (for the given project)
function export_pootle_project_translations_to_temp_dirs() {
	project="$1"
	regenerate_file_stores "$project"
	copy_pootle_project_translations_to_temp_dirs "$project"
}

# copies exported translations to prop_out dirs for further processing,
# (for the given project)
function copy_pootle_project_translations_to_temp_dirs() {
	project="$1"
	logt 3 "$project: Copying exported translations from podir into temp dirs"

	# here we need the actual contents in $PODIR/$project instead of the locale set
	for language in $(ls "$PODIR/$project"); do
		if [[ "$language" =~ $lang_file_rexp ]]; then
			logt 0 -n  "$(get_locale_from_file_name $language) "
			cp -f  "$PODIR/$project/$language" "$TMP_PROP_OUT_DIR/$project/"
		fi
	done
	check_command
}

function dump_store() {
	project="$1";
	locale="$2";
	langFile="$3";
	storeId=$(get_store_id $project $locale)
	logt 4 "Dumping store id $storeId into $langFile"
	export_targets "$storeId" "$langFile"
}

function prepare_output_dir() {
	project="$1"
	logt 2 "$project: cleaning output working dirs"
	clean_dir "$TMP_PROP_OUT_DIR/$project"
}

# creates temporary working dirs for working with pootle output
function clean_temp_output_dirs() {
	logt 1 "Preparing project output working dirs..."
	logt 2 "Cleaning general output working dirs"
	clean_dir "$TMP_PROP_OUT_DIR/"
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		prepare_output_dir "$project"
	done
}