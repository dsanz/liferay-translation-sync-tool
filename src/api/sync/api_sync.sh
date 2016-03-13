function sync() {
	loglc 1 $RED "Begin Synchronization"
	display_source_projects_action
	create_backup_action
	update_pootle_db_from_templates
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
	charc["P"]=$YELLOW; chart["P"]="Sources translated, pootle untranslated. Source value goes to Pootl"
	charc["p"]=$LILA; chart["p"]="Pootle and sources translated, source value != template value, pootle value = template value. Source value goes to Pootle"
	charc["-"]=$COLOROFF; chart["-"]="Source code has a translation which key no longer exists. Won't update pootle. build-lang should remove it from sources"
	charc["·"]=$CYAN; chart["·"]="Same, valid translation in pootle and sources (no-op)"

	# to sources
	charc["o"]=$WHITE; chart["o"]="Overriden from ext file"
	charc["x"]=$LILA; chart["x"]="Pootle and sources translated, different translations (conflict/improvement, Pootle value goes to sources)"
	charc["s"]=$LILA; chart["s"]="Pootle and sources translated, source value = template value, pootle value != template value. Pootle value goes to sources"
	charc["S"]=$GREEN; chart["S"]="Source untranslated, pootle translated. Pootle value goes to sources"

	for char in ${!charc[@]}; do
		loglc 8 ${charc[$char]} "'$char' ${chart[$char]}.  "
	done;

    sync_project_translations $POOTLE_PROJECT_ID
}

function sync_project_translations() {
	pootle_project="$1"

	logt 2 "Synchronizing translations from/to pootle project $pootle_project"

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

			for sources_project in "${!AP_PROJECT_NAMES[@]}"; do
				# TODO: check if we need a sort of source code project blacklist here
				if [[ $sources_project != $pootle_project ]]; then
					# this has to be read once per sources project and locale
					read_source_code_language_file $sources_project $language

					sync_project_locale_translations $pootle_project $sources_project $language

					logt 4 -n "Garbage collection (sources: $sources_project, $locale)... "
					clear_keys "$(get_source_code_language_prefix $sources_project $locale)"
					check_command
				fi
			done

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
				PvalStore=${T["$storePrefix$Skey"]}                                      # get store value
				PValTpl=${T["$templatePrefix$Skey"]}                                     # get template value

				if exists_ext_value $extPrefix $Skey; then                               # has translation to be overriden?
					S[$Skey]=${T["$extPrefix$Skey"]}                                     #   override translation using the ext file content
					char="o"                                                             #
				elif ! exists_key "$templatePrefix" "$Skey"; then                        # otherwise, does key exist in template file?
					char="-"                                                             #   key does not exist in pootle template. We've just updated from templates so do nothing
				else                                                                     # otherwise, key exists in pootle template, so we can update pootle AND sources now
					if is_translated_value "$PvalStore"; then                            #   is the pootle value translated?
						is_pootle_translated=true;                                       #     dump_store does not export empty values with the template value as native pootle sync_stores does
					else                                                                 #
						is_pootle_translated=false;                                      #
					fi;                                                                  #
                                                                                         #
					if [[ "$Sval" != "$PValTpl" ]] && is_translated_value "$Sval"; then  #   is the sources value translated?
						is_sources_translated=true;                                      #     sources are translated if the value is not empty, is not an auto-translation and its value is different from the template
					else                                                                 #
		  				is_sources_translated=false;                                     #
					fi;                                                                  #
                                                                                         #
					if $is_sources_translated; then                                      # source code value is translated. Is pootle one translated too?
						if $is_pootle_translated; then                                   # pootle value is translated. This includes anything translator write, even english texts
							if [[ "$PvalStore" == "$Sval" ]]; then                       #   are pootle and source translation the same?
								char="·"                                                 #     the ndo nothing
							else                                                         #   translations are different. we have a conflict...
								if [[ "$Sval" == "PValTpl" ]]; then                      #     source value is like the template, whereas store value not.
									char="p"                                             #
									S[$Skey]="$PvalStore"                                #        Pootle wins. Store pootle translation in sources array
								elif [[ "$PvalStore" == "PValTpl" ]]; then               #     store value is like the template, whereas source not.
									char="p"                                             #
									P[$Skey]="$Sval";                                    #        Source wins. Store source value in pootle array
								else                                                     #    none of the translated values is equal to the template.
									char="x"                                             #
									S[$Skey]="$PvalStore"                                #        Pootle wins. We assume pootle gets improvements all the time
									                                                     #        TODO: improve this by examining unit mtime and commit line last time (git blame) and use the latest
								fi                                                       #
							fi                                                           #
						else                                                             # store value is untranslated. Either no one wrote there or contains an old "auto" translation
							char="P"                                                     #
							P[$Skey]="$Sval";                                            #    Store source value in pootle array
						fi                                                               #
					else                                                                 # Source code value is not translated. We have a chance to give it a value
						if $is_pootle_translated; then                                   #    is pootle value translated?
							S[$Skey]="$PvalStore"                                        #       Pootle wins. Store pootle translation in sources array
							char="S"                                                     #
						else                                                             #
							char="u"                                                     #
						fi                                                               #
					fi                                                                   #
				fi                                                                       #
			fi                                                                           #
			loglc 0 "${charc[$char]}" -n "$char"                                         #
		else                                                                             #
			char="#"                                                                     # is it a comment line
		fi;                                                                              #
	done < $source_lang_file                                                             # feed from source code language file
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
			val="${S[$key]}"
			logt 4 "$key=$val"
			sed -i "s/^$key=.*/$key=${val//\//\\/}/" $source_lang_file
		done;
	else
		logt 4 "No translations to update in $sources_project from $pootle_project ($locale)"
	fi

	set +f
	unset P
	unset S
}