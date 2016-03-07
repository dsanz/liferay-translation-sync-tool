function merge_pootle_projects_action() {
	merge_pootle_project_publishing

}

#
# First merge projects impl: based on transferring translation units in the db. We thus keep things like word count
function merge_pootle_projects_unit_transfer() {
	source_project_codes="$2"
	source_project_list="$(echo $source_project_codes | sed 's: :\n:g' | sort)"
	logt 1 "Merging projects: $source_project_codes"
	logt 1 "into project: $target_project_code"

	read_pootle_projects_and_locales

	prepare_output_dir "$target_project_code"

	while read project; do
		if exists_project_in_pootle_DB $project; then
			logt 2 "Joining source pootle project template: $project"
			cat $PODIR/$project/$FILE.$PROP_EXT >> $TMP_PROP_OUT_DIR/$target_project_code/$FILE.$PROP_EXT
		else
		 	logt 2 "Skippig $project as it does not exist in pootle"
		fi
	done <<< "$source_project_list"

	# just create the new project and update the templates
	add_pootle_project_action $target_project_code "$target_project_code" 0
	provision_project_template $target_project_code $target_project_code $TMP_PROP_OUT_DIR/$target_project_code

	# now, transfer stores
	while read project; do
		if exists_project_in_pootle_DB $project; then
			logt 2 "Transferring source pootle project stores: $project"

			for locale in "${POOTLE_PROJECT_LOCALES[@]}"; do
				language_file=$(get_file_name_from_locale $locale);
				storeFile="$TMP_PROP_OUT_DIR/$project/$language_file.store"
				transfer_store "$project" "$target_project_code" "$locale"
			done;
		else
		 	logt 2 "Skippig $project as it does not exist in pootle"
		fi
	done <<< "$source_project_list"

}

#
# First merge projects impl: based on exporting and republishing
function merge_pootle_projects_publishing() {
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
				cat $storeFile >> $TMP_PROP_OUT_DIR/$target_project_code/$language_file
			done;

			regenerate_file_stores "$project"
			cat $PODIR/$project/$FILE.$PROP_EXT >> $TMP_PROP_OUT_DIR/$target_project_code/$FILE.$PROP_EXT
		else
		 	logt 2 "Skippig $project as it does not exist in pootle"
		fi
	done <<< "$source_project_list"

	# process translations for each language:
	#   skip automatic copy/translations: publish translations will take care
	#   skip english value unless DB contains it: dump store should take care (TODO: double check!!)

	if exists_project_in_pootle_DB $target_project_code; then
		logt2 "Merging with existing project $target_project_code"
		regenerate_file_stores $target_project_code
		# add the target project template to the composite template
		cat $PODIR/$target_project_code/$FILE.$PROP_EXT >> $TMP_PROP_OUT_DIR/$target_project_code/$FILE.$PROP_EXT

        # update from templates
		logt 2 "Setting pootle project template for $target_project_code"
		update_from_templates $target_project_code "$TMP_PROP_OUT_DIR/$target_project_code"

		provision_project_translations $target_project_code $target_project_code $TMP_PROP_OUT_DIR/$target_project_code
	else
		# provision new project (not from sources!)
		start_pootle_session
		provision_full_project_base $target_project_code $target_project_code $TMP_PROP_OUT_DIR/$target_project_code
		close_pootle_session
	fi;

	refresh_project_stats $target_project_code
}