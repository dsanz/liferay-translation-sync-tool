function sync() {
	loglc 1 $RED "Begin Synchronization"
	display_source_projects_action
	create_backup_action
	update_pootle_db_from_templates_repo_based
	clean_temp_input_dirs
	clean_temp_output_dirs
	restore_file_ownership

	# merge
	sync_translations

	do_commit false false "Translations sync from translate.liferay.com"
	build_lang
	do_commit true true "build-lang"

	restore_file_ownership
	refresh_stats_repo_based

	loglc 1 $RED "End Synchronization"
}


function sync_translations() {
	logt 1 "Synchronizing translations"

	logt 2 "Legend:"
	unset charc
	unset chart
	declare -gA charc # colors
	declare -gA chart # text legend

	# to pootle
	charc["#"]=$COLOROFF; chart["#"]="comment/blank line"
	charc["R"]=$YELLOW; chart["R"]="reverse-path (sources translated, pootle untranslated). Will be published to Pootle"
	charc["u"]=$BLUE; chart["u"]="source code untranslated. Can not update pootle"
	charc["-"]=$WHITE; chart["-"]="source code has a translation which key no longer exists. Won't update pootle"
	charc["·"]=$GREEN; chart["·"]="no-op (same, valid translation in pootle and sources)"

	# to sources
	charc["!"]=$RED; chart["!"]="uncovered case"
	charc["o"]=$WHITE; chart["o"]="overriden from ext file"
	charc["e"]=$RED; chart["e"]="English value is ok, was translated on purpose using Pootle"
	charc["r"]=$YELLOW; chart["r"]="reverse-path (sources translated, pootle is untranslated). Will be published to Pootle"
	charc["a"]=$CYAN; chart["a"]="ant build-lang will do (sources and pootle untranslated)"
	charc["u"]=$BLUE; chart["u"]="untranslated, pick existing source value (Pootle untranslated, source auto-translated or auto-copied)"
	charc["x"]=$LILA; chart["x"]="conflict/improvement Pootle wins (pootle and sources translated, different values). Review $copyingLogfile "
	charc["·"]=$COLOROFF; chart["·"]="no-op (same, valid translation in pootle and sources)"
	charc["p"]=$GREEN; chart["p"]="valid translation coming from pootle, sources untranslated"
	charc["#"]=$COLOROFF; chart["#"]="comment/blank line"

	for char in ${!charc[@]}; do
		loglc 8 ${charc[$char]} "'$char' ${chart[$char]}.  "
	done;

	for git_root in "${!GIT_ROOTS[@]}"; do
		sync_project_translations $git_root
	done;
}

function sync_project_translations() {
	git_root="$1"

	destination_pootle_project="${GIT_ROOT_POOTLE_PROJECT_NAME[$git_root]}"
	source_project_list="$(echo ${AP_PROJECTS_BY_GIT_ROOT["$git_root"]} | sed 's: :\n:g' | sort)"

	logt 2 "$destination_pootle_project"

	# this has to be read once per destination project
	read_pootle_exported_template $destination_pootle_project

	start_pootle_session
	for locale in "${POOTLE_PROJECT_LOCALES[@]}"; do
		language=$(get_file_name_from_locale $locale)
		if [[ "$locale" != "en" && "$language" =~ $trans_file_rexp ]]; then
			logt 2 "$destination_pootle_project: $locale"

			# these have to be read once per source project and language
			read_pootle_store $destination_pootle_project $language

			# iterate all projects in the destination project list and 'backport' to them
			while read source_project; do
				if [[ $source_project != $destination_pootle_project ]]; then
					# this has to be read once per target project and locale
					read_source_code_language_file $source_project $language

					refill_incoming_translations_repo_based $destination_pootle_project $source_project $language

					logt 4 -n "Garbage collection (source: $source_project, $locale)... "
					clear_keys "$(get_source_code_language_prefix $source_project $locale)"
					check_command
				fi
			done <<< "$source_project_list"

			logt 3 -n "Garbage collection (target: $destination_pootle_project, $locale)... "
			clear_keys "$(get_store_language_prefix $destination_pootle_project $locale)"
			check_command
		fi
	done
	close_pootle_session

	logt 2 -n "Garbage collection (source project: $destination_pootle_project)... "
	unset K
	unset T
	declare -gA T;
	declare -ga K;
	check_command
}
