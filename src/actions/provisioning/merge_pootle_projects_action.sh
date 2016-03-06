function merge_pootle_projects_action() {
	target_project_code="$1"
	source_project_codes="$2"
	source_project_list="$(echo $source_project_codes | sed 's: :\n:g' | sort)"
	logt 1 "Merging projects: $source_project_codes"
	logt 1 "into project: $target_project_code"

	read_pootle_projects_and_locales

	prepare_output_dir "$target_project_code"

	while read project; do
		if exists_project_in_pootle_DB $project; then
			logt 2 "Processing source pootle project: $project"
			# clean output dirs for source project code
			prepare_output_dir "$project"

			# export all source project files: sync_store or dump_store?
			for locale in "${POOTLE_PROJECT_LOCALES[@]}"; do
				language_file=$(get_file_name_from_locale $locale);
				storeFile="$TMP_PROP_OUT_DIR/$project/$language_file.store"
				dump_store "$project" "$locale" "$storeFile"
				cat $storeFile >> $PODIR/$target_project_code/$language_file
			done;

			regenerate_file_stores "$project"
			cat $PODIR/$project/$FILE.$PROP_EXT >> $PODIR/$target_project_code/$FILE.$PROP_EXT
		else
		 	logt 2 "Skippig $project as it does not exist in pootle"
		fi
	done <<< "$source_project_list"

	# process translations for each language:
	#   skip automatic copy/translations: publish translations will take care
	#   skip english value unless DB contains it: dump store should take care (TODO: double check!!)

	# provision new project (not from sources!)
	start_pootle_session
	provision_full_project_base $target_project_code $target_project_code  $PODIR/$target_project_code/
	close_pootle_session
}