####
## Top-level functions
####

# src2pootle implements the sync bewteen liferay source code and pootle storage
# - backups everything
# - pulls from upstream the master branch
# - updates pootle from the template of each project (Language.properties) so that:
#   . only keys contained in Language.properties are processed
#   . new/deleted keys in Language.properties are conveniently updated in pootle project
# - updates any translation committed to liferay source code since last pootle2src sync (pootle built-in
#     'update-translation-projects' can't be used due to a pootle bug, we do this with curl)

# preconditions:
#  . project must exist in pootle, same 'project code' than git source dir (for plugins)
#  . portal/plugin sources are available and are under git control
function src2pootle() {
	loglc 1 $RED "Begin Sync[Liferay source code -> Pootle]"
	display_source_projects_action
	create_backup_action
	update_pootle_db_from_templates_repo_based
	clean_temp_input_dirs
	post_language_translations_repo_based # bug #1949
	restore_file_ownership
	refresh_stats_repo_based
	loglc 1 $RED "End Sync[Liferay source code -> Pootle]"
}

function post_language_translations_repo_based() {
	generate_additions
	post_new_translations_repo_based
}

function generate_additions() {
	logt 1 "Calculating committed translations from latest export commit, for each project/language"

	for git_root in "${!GIT_ROOTS[@]}"; do
		target_project="${GIT_ROOT_POOTLE_PROJECT_NAME[$git_root]}"
		project_list="$(echo ${AP_PROJECTS_BY_GIT_ROOT["$git_root"]} | sed 's: :\n:g' | sort)"
		projects=$(echo "$project_list" | wc -l)

		cd $git_root
		logt 2 "Computing commits going to target project $target_project ($git_root)"
		clean_dir "$TMP_PROP_IN_DIR/$target_project"

		while read source_project; do
			local path="${AP_PROJECT_SRC_LANG_BASE["$source_project"]}"
			cd $path > /dev/null 2>&1
			translation_files=$(ls ${FILE}${LANG_SEP}*.$PROP_EXT 2>/dev/null)
			logt 3 "Translations commited to source project: $source_project $(echo "$translation_files" | wc -w) language files"
			for file in $translation_files; do
				if [[ "$file" != "${FILE}${LANG_SEP}en.${PROP_EXT}" ]]; then
					commit=$(get_last_export_commit "$path" "$file")
					generate_addition "$source_project" "$path" "$file" "$commit" "$target_project"
				fi;
			done
			log
		done <<< "$project_list"
	done;
}

# this function works either for module-based or repo-based layout
function generate_addition() {
	source_project="$1"
	local path="$2"
	file="$3"
	commit="$4"
	target_project="$5"

	cd $path > /dev/null 2>&1
	#logt 5 -n "Generating additions from: git diff $commit $file "
	git diff $commit $file | sed -r 's/^[^\(]+\(Automatic [^\)]+\)$//' | grep -E "^\+[^=+][^=]*" | sed 's/^+//g' > $TMP_PROP_IN_DIR/$source_project/$file
	number_of_additions=$(cat "$TMP_PROP_IN_DIR/$source_project/$file" | wc -l)
	color="$GREEN"
	if [[ $number_of_additions -eq 0 ]]; then
		rm "$TMP_PROP_IN_DIR/$source_project/$file"
		color="$LIGHT_GRAY"
	else
		cat "$TMP_PROP_IN_DIR/$source_project/$file" >> "$TMP_PROP_IN_DIR/$target_project/$file"
	fi;
	logc "$color" -n "[$(get_locale_from_file_name $file) $commit ($number_of_additions)] "
}

function post_new_translations_repo_based() {
	logt 1 "Posting commited translations from last update"
	logt 2 "Creating session in Pootle"
	start_pootle_session

	for project in "${GIT_ROOT_POOTLE_PROJECT_NAME[@]}"; do
		post_new_project_translations "$project"
	done;
	logt 2 "Closing session in Pootle"
	close_pootle_session
}

function post_new_project_translations() {
	project="$1"

	logt 2 "Uploading translations for project $project"
	cd $TMP_PROP_IN_DIR/$project > /dev/null 2>&1
	files="$(ls ${FILE}${LANG_SEP}*.${PROP_EXT} 2>/dev/null)"
	if [[ "$files" == "" ]]; then
		logt 3 "No translations to upload!"
	else
		for file in $files; do
			locale=$(get_locale_from_file_name $file)
			post_file_batch "$project" "$locale"
		done;
	fi;
}

function get_last_export_commit() {
	local path="$1"
	file="$2"

	msg="$(get_locale_from_file_name $file):"
	cd $path
	child_of_last_export="HEAD"
	last_export_commit=$(git log -n 1 --grep "$product_name" --after="2016-01-01" --format=format:"%H" $file)
	if [[ $last_export_commit == "" ]]; then
		#msg="$msg (no export commit containing $product_name) "
		last_export_commit=$(git log -n 1 --grep "$old_product_name" --after="2016-01-01" --format=format:"%H" $file)
	fi;
	if [[ $last_export_commit == "" ]]; then
		: #msg="$msg (no export commit containing $product_name) "
	else
		child_of_last_export=$(git rev-list --children --after="2016-01-01" HEAD | grep "^$last_export_commit" | cut -f 2 -d ' ')
	fi;
	echo "$child_of_last_export";
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
	local path=$(get_pootle_path $project $derived_locale)

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

function refresh_stats() {
	logt 1 "Refreshing Pootle stats..."
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		refresh_project_stats $project
	done
}

function refresh_stats_repo_based() {
	logt 1 "Refreshing Pootle stats..."
	for project in "${GIT_ROOT_POOTLE_PROJECT_NAME[@]}"; do
		refresh_project_stats $project
	done
}

function refresh_project_stats() {
	project="$1"

	logt 2 "$project: refreshing stats"
	call_manage "refresh_stats" "--project=$project" "-v 0"
	check_command
}

#
# deprecated
#

function post_new_translations() {
	logt 1 "Posting commited translations from last update"
	logt 2 "Creating session in Pootle"
	start_pootle_session
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		post_new_project_translations "$project"
	done;
	logt 2 "Closing session in Pootle"
	close_pootle_session
}

function post_language_translations() {
	generate_additions
	post_new_translations
}