function display_stats() {
	read_pootle_projects_and_locales
	logt 1 "Statistics: # and % of translated keys"

	for locale in "${POOTLE_PROJECT_LOCALES[@]}"; do
		logt 2 "$locale"
		translations_filename="$FILE$LANG_SEP$locale.$PROP_EXT"
		template_filename="$FILE.$PROP_EXT"

		for git_root in "${!GIT_ROOTS[@]}"; do
			project_list="$(echo ${AP_PROJECTS_BY_GIT_ROOT["$git_root"]} | sed 's: :\n:g' | sort)"
			projects=$(echo "$project_list" | wc -l)
			logt 3 "Git root: $git_root ($projects projects)."
			while read project; do
				project_name="${AP_PROJECT_NAMES[$project]}"
				src_lang_base="${AP_PROJECT_SRC_LANG_BASE[$project]}"
				key_count=$(cat $src_lang_base/$template_filename | grep -E "^([^=]+)="  | wc -l)
				translation_count=$(cat $src_lang_base/$translations_filename | grep -E "^([^=]+)=" | wc -l)
				automatic_count=$(cat $src_lang_base/$translations_filename | grep -E "^([^=]+)=" | grep -E "\(Automatic [^\)]+{4,11}\)$" | wc -l)
				untranslated_count=$(( $key_count - $translation_count + $automatic_count ))
				translated_count=$(( $key_count - $untranslated_count ))

				loglc 0 $YELLOW -n "$(printf "%-7s %-60s %-6s" "[$locale]" "$project_name " "$key_count")"
				loglc 0 $GREEN -n "$(printf "%-4s (%-4s)  " "$translated_count" "$(( $translated_count * 100 / $key_count ))%")"
				loglc 0 $RED -n "$(printf "%-4s (%-4s)  " "$untranslated_count" "$(( $untranslated_count * 100 / $key_count ))%")"
				log
			done <<< "$project_list"
		done
	done;
}