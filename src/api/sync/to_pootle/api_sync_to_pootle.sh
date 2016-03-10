####
## Top-level functions
####

# src2pootle implements the sync bewteen liferay source code and pootle storage
# - backups everything
# - pulls from upstream the master branch
# - updates pootle from the template of each project (Language.properties) so that:
#   . only keys contained in Language.properties are processed
#   . new/deleted keys in Language.properties are conveniently updated in pootle project
# - updates any translation committed to liferay source code not present in pootle
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
	process_incoming_translations_repo_based
	restore_file_ownership
	refresh_stats_repo_based
	loglc 1 $RED "End Sync[Liferay source code -> Pootle]"
}

function process_incoming_translations_repo_based() {
	logt 1 "Processing translations to import"
	logt 2 "Legend:"
	unset charc
	unset chart
	declare -gA charc # colors
	declare -gA chart # text legend
	charc["#"]=$COLOROFF; chart["#"]="comment/blank line"
	charc["R"]=$YELLOW; chart["R"]="reverse-path (sources translated, pootle untranslated). Will be published to Pootle"
	charc["u"]=$BLUE; chart["u"]="source code untranslated. Can not update pootle"
	charc["-"]=$WHITE; chart["-"]="source code has a translation which key no longer exists. Won't update pootle"
	charc["·"]=$GREEN; chart["·"]="no-op (same, valid translation in pootle and sources)"
	for char in ${!charc[@]}; do
		loglc 8 ${charc[$char]} "'$char' ${chart[$char]}.  "
	done;

	for git_root in "${!GIT_ROOTS[@]}"; do
		process_incoming_project_translations_repo_based $git_root
	done;
}

# process translations from a repo-based projet layout
function process_incoming_project_translations_repo_based() {
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


function refill_incoming_translations_repo_based() {
	set -f
	destination_pootle_project="$1";
	source_project="$2";
	language="$3";

	locale=$(get_locale_from_file_name $language)

	# involved file paths
	source_lang_file="${AP_PROJECT_SRC_LANG_BASE["$source_project"]}/$language"

	# destination project prefixes for array accessing
	templatePrefix=$(get_template_prefix $destination_pootle_project $locale)
	storePrefix=$(get_store_language_prefix $destination_pootle_project $locale)

	# source code project prefixes for array accessing
	sourceCodePrefix=$(get_source_code_language_prefix $source_project $locale)

	declare -A R  # reverse translations

	logt 4 -n "Importing $source_project -> $destination_pootle_project ($locale): "
	done=false;
	OLDIFS=$IFS
	IFS=
	# read the target language file. Variables meaning:
	# Skey: source file language key
	# Sval: source file language value. This one will be imported in pootle if needed
	# TvalStore: target pootle language value associated to Skey (comes from dumped store)
	# TvalTpl: target pootle template value associated to Skey

	until $done; do
		if ! read -r line; then
			done=true;
		fi;
		if [ ! "$line" == "" ]; then
			char="#"
			if is_key_line "$line" ; then
				[[ "$line" =~ $kv_rexp ]] && Skey="${BASH_REMATCH[1]}" && Sval="${BASH_REMATCH[2]}"
				TvalStore=${T["$storePrefix$Skey"]}            # get store value
				TvalTpl=${T["$templatePrefix$Skey"]}           # get template value

				if ! exists_key "$templatePrefix" "$Skey"; then
					char="-"
				else
					# if Sval is untranslated, nothing to do
					char="u"
					if [[ "$Sval" != "$TvalTpl" ]]; then           # source code value has to be translated
						if is_translated_value "$Sval"; then       # source code value is translated. Is pootle one translated too?
							if [[ "$TvalStore" == "" ]]; then               # store value is empty. No one wrote there
								char="R"
								R[$Skey]="$Sval";
							elif ! is_translated_value "$TvalStore"; then   # store value contains an old "auto" translation
								char="R"
								R[$Skey]="$Sval";
							else                                            # store value is translated.
								char="·"
							fi
						fi
					fi
				fi
			fi
			loglc 0 "${charc[$char]}" -n "$char"
		fi;
	done < $source_lang_file
	IFS=$OLDIFS

	log

	if [[ ${#R[@]} -gt 0 ]];  then
		storeId=$(get_store_id $destination_pootle_project $locale)
		local path=$(get_pootle_path $destination_pootle_project $locale)
		logt 4 "Submitting ${#R[@]} translations..."
		for key in "${!R[@]}"; do
			upload_submission "$key" "${R[$key]}" "$storeId" "$path"
		done;
	else
		logt 4 "No translations to import $source_project -> $destination_pootle_project ($locale)"
	fi

	set +f
	unset R
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
}