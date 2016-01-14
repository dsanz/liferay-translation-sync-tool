function display_stats() {
	read_pootle_projects_and_locales
	logt 1 "Statistics: # and % of translated keys"

	for locale in "${POOTLE_PROJECT_LOCALES[@]}"; do
		logt 2 "$locale"
		translations_filename="$FILE$LANG_SEP$locale.$PROP_EXT"
		template_filename="$FILE.$PROP_EXT"

		per_locale_key_count=0
		per_locale_translated_count=0
		per_locale_untranslated_count=0

		for git_root in "${!GIT_ROOTS[@]}"; do
			project_list="$(echo ${AP_PROJECTS_BY_GIT_ROOT["$git_root"]} | sed 's: :\n:g' | sort)"
			projects=$(echo "$project_list" | wc -l)
			logt 3 "Git root: $git_root ($projects projects)."

			per_root_key_count=0
			per_root_translated_count=0
			per_root_untranslated_count=0
			while read project; do
				project_name="${AP_PROJECT_NAMES[$project]}"
				src_lang_base="${AP_PROJECT_SRC_LANG_BASE[$project]}"
				key_count=$(cat $src_lang_base/$template_filename | grep -E "^([^=]+)="  | wc -l)
				translation_count=$(cat $src_lang_base/$translations_filename | grep -E "^([^=]+)=" | wc -l)
				automatic_count=$(cat $src_lang_base/$translations_filename | grep -E "^([^=]+)=" | grep -E "\(Automatic [^\)]+{4,11}\)$" | wc -l)
				untranslated_count=$(( $key_count - $translation_count + $automatic_count ))
				translated_count=$(( $key_count - $untranslated_count ))

				(( per_root_key_count += key_count ))
				(( per_root_translated_count += translated_count ))
				(( per_root_untranslated_count += untranslated_count ))

				loglc 0 $YELLOW -n "$(printf "%-7s %-60s %-6s keys      " "[$locale]" "$project_name " "$key_count")"
				loglc 0 $GREEN -n "$(printf "[%-4s translated - %-4s percent]    " "$translated_count" "$(( $translated_count * 100 / $key_count ))")"
				loglc 0 $RED -n "$(printf "[%-4s untranslated - %-4s percent]" "$untranslated_count" "$(( $untranslated_count * 100 / $key_count ))")"
				log
			done <<< "$project_list"

			logt 3 "Totals per git root and locale $locale:"
			loglc 0 $YELLOW -n "$(printf "%-7s %-60s %-6s keys      " "[$locale]" "$git_root " "$per_root_key_count")"
			loglc 0 $GREEN -n "$(printf "[%-4s translated - %-4s percent]     " "$per_root_translated_count" "$(( $per_root_translated_count * 100 / $per_root_key_count ))")"
			loglc 0 $RED -n "$(printf "[%-4s untranslated - %-4s percent]" "$per_root_untranslated_count" "$(( $per_root_untranslated_count * 100 / $per_root_key_count ))")"
    		log
    		log
			(( per_locale_key_count += per_root_key_count ))
			(( per_locale_translated_count += per_root_translated_count ))
			(( per_locale_untranslated_count += per_root_untranslated_count ))
		done
		logt 2 "Totals per locale $locale:"
		loglc 0 $YELLOW -n "$(printf "%-7s %-6s keys      " "[$locale]" "$per_locale_key_count")"
		loglc 0 $GREEN -n "$(printf "[%-4s translated - %-4s percent]     " "$per_locale_translated_count" "$(( $per_locale_translated_count * 100 / $per_locale_key_count ))")"
		loglc 0 $RED -n "$(printf "[%-4s untranslated - %-4s percent]" "$per_locale_untranslated_count" "$(( $per_locale_untranslated_count * 100 / $per_locale_key_count ))")"

	done;
}