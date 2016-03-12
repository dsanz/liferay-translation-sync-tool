function merge_pootle_projects_action() {
	#merge_pootle_projects_publishing "$1" "$2"
	read_pootle_projects_and_locales
	merge_pootle_projects_DB "$1"
}


function merge_pootle_projects_DB() {
	target_project_code="$1";
	logt 2 "Merging all projects in $target_project_code"
	check_dir "$TMP_PROP_OUT_DIR"

	locale_count=0
    (( total_locales=${#POOTLE_PROJECT_LOCALES[@]} + 1 ))
	merge_pootle_project_locale $target_project_code "templates" $locale_count $total_locales
	for locale in "${POOTLE_PROJECT_LOCALES[@]}"; do
		(( locale_count++ ))
		merge_pootle_project_locale $target_project_code $locale $locale_count $total_locales
	done
}

function merge_pootle_project_locale() {
	target_project_code="$1"
	locale="$2"
	locale_count=$3
	total_locales=$4

	targetStoreId=$(get_store_id $target_project_code $locale)
	logt 2 "Processing locale $locale [$locale_count / $total_locales], target store $targetStoreId"
	sort_indexes $targetStoreId
	max_index=$(get_max_index $targetStoreId)
	for source_project_code in "${POOTLE_PROJECT_CODES[@]}"; do
		if [[ "$source_project_code" != "$target_project_code" ]]; then
			if ! is_whitelisted $source_project_code; then
				merge_units $targetStoreId $source_project_code $locale $locale_count $total_locales
			else
				logt 3 "Skipping whitelisted $source_project_code"
			fi
		else
			logt 3 "Skipping $source_project_code as can't be merged with itself"
		fi;
	done
}

function merge_units() {
	targetStoreId="$1"
	source_project_code="$2"
	locale="$3"
	locale_count=$4
	total_locales=$5

	max_index=$(get_max_index $targetStoreId)
	sourceStoreId=$(get_store_id $source_project_code $locale)

	logt 3 "Merging units from project $source_project_code ($locale) [$locale_count / $total_locales], store $sourceStoreId into $targetStoreId. Starting at index $max_index"
	get_units_unitid_by_storeId $sourceStoreId "$TMP_PROP_OUT_DIR/$sourceStoreId"
	done=false;
	until $done; do
		read unit || done=true
		if [[ "$unit" != "" ]]; then
			# cad="12345@6789"; i=$(expr index "$cad" "@"); echo ${cad:0:i-1}; echo ${cad:i}
			pos=$(expr index "$unit" "@")
			unit_identifier=${unit:0:pos-1}
			unitid=${unit:pos}

			existing_unitid=$(get_unitid_storeId_and_unitid $targetStoreId $unitid)
			if [[ $existing_unitid == "" ]]; then # do this only if target store does not contain the same unitid
				(( max_index++ ))
				# change the unit index while it still is in the source store
				update_unit_index_by_store_and_unit_id $sourceStoreId $unit_identifier $max_index
				# change the unit store
				update_unit_store_id_by_unit_id $unit_identifier $targetStoreId
				log -n "[$unit_identifier($max_index)] "
			else
				log -n "[$unit_identifier(*)] "
			fi;
		fi;
	done < "$TMP_PROP_OUT_DIR/$sourceStoreId";
	#rm "$TMP_PROP_OUT_DIR/$sourceStoreId"
	log
	# TODO: harmonize source_f across the same unitid
}

function sort_indexes() {
	storeId="$1"
	new_index=0
	max_index=$(get_max_index $storeId)
	unit_count=$(count_targets $storeId)

	logt 3 "Sorting indexes in target store $storeId. Max index=$max_index, Unit count=$unit_count."
	get_units_index_by_storeId $storeId "$TMP_PROP_OUT_DIR/$storeId"
	done=false;
	until $done; do
		read unit || done=true
		if [[ "$unit" != "" ]]; then
			pos=$(expr index "$unit" "@")
			unitId=${unit:0:pos-1}
			unitIndex=${unit:pos}
			if [[ "$unitIndex" != "$new_index" ]]; then
				update_unit_index_by_store_and_unit_id $storeId $unitId $new_index
				log -n "[${unitId}_$unitIndex>$new_index] "
			else
				log -n "[${unitId}_$unitIndex_index] "
			fi
			(( new_index++ ))
		fi;
	done < "$TMP_PROP_OUT_DIR/$storeId";
	log
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

	start_pootle_session

	if exists_project_in_pootle_DB $target_project_code; then
		logt 2 "Merging with existing project $target_project_code"
		regenerate_file_stores $target_project_code
		# add the target project template to the composite template
		cat $PODIR/$target_project_code/$FILE.$PROP_EXT >> $TMP_PROP_OUT_DIR/$target_project_code/$FILE.$PROP_EXT
	fi

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
		 	logt 2 "Skipping $project as it does not exist in pootle"
		fi
	done <<< "$source_project_list"

	# process translations for each language:
	#   skip automatic copy/translations: publish translations will take care
	#   skip english value unless DB contains it: dump store takes care

	if exists_project_in_pootle_DB $target_project_code; then
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

	close_pootle_session
}