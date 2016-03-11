function merge_pootle_projects_action() {
	#merge_pootle_projects_publishing "$1" "$2"
	read_pootle_projects_and_locales
	merge_pootle_projects_DB "$1"
}


function merge_pootle_projects_DB() {
	target_project_code="$1";
	logt 2 "Merging all projects in $target_project_code"
	check_dir "$TMP_PROP_OUT_DIR"

	for locale in "${POOTLE_PROJECT_LOCALES[@]}"; do
		targetStoreId=$(get_store_id $target_project_code $locale)
		logt 2 "Processing locale $locale, target store $targetStoreId"
		sort_indexes $targetStoreId
		max_index=$(get_max_index $targetStoreId)
		for source_project_code in "${POOTLE_PROJECT_CODES[@]}"; do
			if [[ "$source_project_code" != "$target_project_code" ]]; then
				max_index=$(get_max_index $targetStoreId)
				merge_units $targetStoreId $source_project_code $locale $max_index
			fi;
		done
	done
}

function merge_units() {
	targetStoreId="$1"
	source_project_code="$2"
	locale="$3"
	max_index=$4
	sourceStoreId=$(get_store_id $source_project_code $locale)

	logt 3 "Merging units from project $source_project_code ($locale), store $sourceStoreId into $targetStoreId. Starting at index $max_index"
	get_units_by_storeId $sourceStoreId "$TMP_PROP_OUT_DIR/$sourceStoreId"
	done=false;
	until $done; do
		read unit || done=true
		if [[ "$unit" != "" ]]; then
			# cad="12345@6789"; i=$(expr index "$cad" "@"); echo ${cad:0:i-1}; echo ${cad:i}
			i=$(expr index "$unit" "@")
			unit_identifier=${unit:0:i-1}
			unitid=${unit:i}

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
	initial_index=0
	max_index=$(get_max_index $storeId)
	unit_count=$(count_targets $storeId)

	if [[ $max_index > $unit_count ]]; then
		to=$max_index
	else
		to=$unit_count
	fi;
	logt 3 "Sorting indexes in target store $storeId. Max index=$max_index, Unit count=$unit_count. Will iterate to $to"
	for existing_index in $(seq 0 $to); do
		unitId=$(get_unitid_by_store_and_index $storeId $existing_index)
		if [[ "$unitId" != "" ]]; then
			if [[ "$existing_index" != "$initial_index" ]]; then
				update_unit_index_by_store_and_unit_id $storeId $unitId $initial_index
				log -n "[$existing_index>$initial_index] "
				(( initial_index++ ))
			else
				loh -n "[$existing_index] "
			fi
		else
			log -n "[$existing_index > none] "
			if [[ $existing_index == 0 ]]; then  # if first unit is not under index 0, let allow index 1 to be the first one
				(( initial_index++ ))
			fi;
		fi;
	done
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