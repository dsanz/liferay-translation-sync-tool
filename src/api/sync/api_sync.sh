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
	for pootle_project_code in "${POOTLE_PROJECT_CODES[@]}"; do
		export_project_template $pootle_project_code
	done;
	loglc 1 $RED "End Synchronization"
}


function sync_translations() {
	logt 1 "Synchronizing translations"

	logt 2 "Legend:"
	unset charc
	unset chart
	declare -gA charc # colors
	declare -gA chart # text legend

	# common
	charc["!"]=$RED; chart["!"]="Uncovered case (should never show up)"
	charc["#"]=$COLOROFF; chart["#"]="Comment/blank line"
	charc["u"]=$BLUE; chart["u"]="Sources and pootle untranslated"

	# to pootle
	charc["P"]=$YELLOW; chart["P"]="Sources translated, pootle untranslated. Will be published to Pootle"
	charc["-"]=$WHITE; chart["-"]="Source code has a translation which key no longer exists. Won't update pootle. build-lang should remove it"
	charc["·"]=$GREEN; chart["·"]="Same, valid translation in pootle and sources (no-op)"

	# to sources
	charc["o"]=$WHITE; chart["o"]="Overriden from ext file"
	charc["x"]=$LILA; chart["x"]="Pootle and sources translated, different values (conflict/improvement, pootle wins)"
	charc["S"]=$GREEN; chart["S"]="Source untranslated, pootle translated. Will update sources"

	for char in ${!charc[@]}; do
		loglc 8 ${charc[$char]} "'$char' ${chart[$char]}.  "
	done;

	for git_root in "${!GIT_ROOTS[@]}"; do
		sync_project_translations $git_root
	done;
}

function sync_project_translations() {
	git_root="$1"

	pootle_project="${GIT_ROOT_POOTLE_PROJECT_NAME[$git_root]}"
	sources_project_list="$(echo ${AP_PROJECTS_BY_GIT_ROOT["$git_root"]} | sed 's: :\n:g' | sort)"

	logt 2 "Synchronizing translations from/to pootle project $pootle_project"

	# this has to be read once per destination project
	read_pootle_exported_template $pootle_project

	start_pootle_session

	for locale in "${POOTLE_PROJECT_LOCALES[@]}"; do
		language=$(get_file_name_from_locale $locale)
		if [[ "$locale" != "en" && "$language" =~ $trans_file_rexp ]]; then
			logt 2 "$pootle_project: $locale"

			# these have to be read once per pootle project and language
			read_pootle_store $pootle_project $language
			# TODO: really needed? read_pootle_exported_language_file $pootle_project $language
			read_ext_language_file $pootle_project $language

			while read sources_project; do
				if [[ $sources_project != $pootle_project ]]; then
					# this has to be read once per sources project and locale
					read_source_code_language_file $sources_project $language

					sync_project_locale_translations $pootle_project $sources_project $language

					logt 4 -n "Garbage collection (sources: $sources_project, $locale)... "
					clear_keys "$(get_source_code_language_prefix $sources_project $locale)"
					check_command
				fi
			done <<< "$sources_project_list"

			logt 3 -n "Garbage collection (pootle: $pootle_project, $locale)... "
			clear_keys "$(get_store_language_prefix $pootle_project $locale)"
			# TODO: really needed? clear_keys "$(get_exported_language_prefix $pootle_project $locale)"
			clear_keys "$(get_ext_language_prefix $pootle_project $locale)"
			check_command
		fi
	done

	close_pootle_session

	logt 2 -n "Garbage collection (sources: $pootle_project)... "
	unset K
	unset T
	declare -gA T;
	declare -ga K;
	check_command
}

function sync_project_locale_translations() {
	set -f
	pootle_project="$1";
	sources_project="$2";
	language="$3";

	locale=$(get_locale_from_file_name $language)

	# involved file paths
	source_lang_file="${AP_PROJECT_SRC_LANG_BASE["$sources_project"]}/$language"

	# pootle project prefixes for array accessing
	templatePrefix=$(get_template_prefix $pootle_project $locale)
	storePrefix=$(get_store_language_prefix $pootle_project $locale)

	# sources code project prefixes for array accessing
	sourceCodePrefix=$(get_source_code_language_prefix $sources_project $locale)

	declare -A P  # Translations to be published to pootle
	declare -A S  # Translations to update in sources

	logt 4 -n "Synchronizing $sources_project <-> $pootle_project ($locale): "
	done=false;
	OLDIFS=$IFS
	IFS=

	# read the source code language file. Variables meaning:
	# Skey: source file language key
	# Sval: source file language value. This one will be imported in pootle if needed
	# PvalStore: Pootle language value associated to Skey (comes from dumped store)
	# PValTpl: target pootle template value associated to Skey

	# TODO: deal with the case where source file does not exist. should it be generated from pootle store? or be committed as part of build -lang, then resynced later?
	# at least provide a message

	until $done; do
		if ! read -r line; then
			done=true;
		fi;
		if [ ! "$line" == "" ]; then
			char="!"
			if is_key_line "$line" ; then
				[[ "$line" =~ $kv_rexp ]] && Skey="${BASH_REMATCH[1]}" && Sval="${BASH_REMATCH[2]}"
				PvalStore=${T["$storePrefix$Skey"]}            # get store value
				PValTpl=${T["$templatePrefix$Skey"]}           # get template value

				if exists_ext_value $extPrefix $Skey; then     # has translation to be overriden?
					S[$Skey]=${T["$extPrefix$Skey"]}           # |  override translation using the ext file content
					char="o"                                   # |
				elif ! exists_key "$templatePrefix" "$Skey"; then
					char="-"                                           # key does not exist in pootle template. We've just updated from templates so do nothing
				else                                                   # key exists in pootle template, so we can update pootle AND sources now
					is_pootle_translated=$(is_translated_value "$PvalStore")                             # dump_store does not export empty values with the template value as native pootle sync_stores do
					is_sources_translated=$([[ "$Sval" != "$PValTpl" ]] && is_translated_value "$Sval")  # sources are translated if the value is not empty, is not an auto-translatuion and its value is different from the template

					if $is_sources_translated; then                    # source code value is translated. Is pootle one translated too?
						if $is_pootle_translated; then                 # store value is translated. This includes anything translator write, even english texts
							if [[ "$PvalStore" == "$Sval" ]]; then     #   are pootle and source translation the same?
								char="·"
							else                                       #   we have a conflict. Pootle wins as we assume pootle gets improvements all the time
								char="x"
								S[$Skey]="$PvalStore"
							fi
						else                                           # store value is untranslated. Either no one wrote there or contains an old "auto" translation
							char="P"                                   # use the source value for pootle
							P[$Skey]="$Sval";
						fi
					else                                               # source code value is not translated. We have a chance to give it a value
						if $is_pootle_translated; then
							S[$Skey]="$PvalStore"
							char="S"
						else
							char="u"
						fi
					fi
				fi
			fi
			loglc 0 "${charc[$char]}" -n "$char"
		else
			char="#"                                                        # is it a comment line
		fi;
	done < $source_lang_file
	IFS=$OLDIFS

	log

	if [[ ${#P[@]} -gt 0 ]];  then
		storeId=$(get_store_id $pootle_project $locale)
		local path=$(get_pootle_path $pootle_project $locale)
		logt 4 "Submitting ${#P[@]} translations to Pootle:"
		for key in "${!P[@]}"; do
			upload_submission "$key" "${P[$key]}" "$storeId" "$path"
		done;
	else
		logt 4 "No translations to publish to pootle $pootle_project from $sources_project ($locale)"
	fi

	if [[ ${#S[@]} -gt 0 ]];  then
		logt 4 "Updating ${#S[@]} translations in sources:"
		for key in "${!S[@]}"; do
			logt 4 "$key=${P[$key]}"
			write_translation $source_lang_file $key "${P[$key]}"
		done;
	else
		logt 4 "No translations to publish to pootle $pootle_project from $sources_project ($locale)"
	fi

	set +f
	unset R
	unset S
}

function write_translation() {
	source_lang_file="$1"
	key="$2"
	value="$3"

	sed -i "s/^$key=.*/$key=${value//\//\\/}/" $source_lang_file
}