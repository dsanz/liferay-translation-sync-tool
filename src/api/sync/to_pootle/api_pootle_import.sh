function update_from_templates() {
	project="$1"
	src_dir="$2"

	logt 3 "Updating the set of translatable keys for project $project"

	if [[ "$src_dir" != "$PODIR/$project" ]]; then
		logt 4 -n "Copying template to PODIR "
		cp "$src_dir/${FILE}.$PROP_EXT" "$PODIR/$project"
		check_command
	else
		logt 4 "I've been instructed to sync directly from PODIR"
	fi
	# Update database as well as file system to reflect the latest version of translation templates
	logt 3 "Updating Pootle templates from $PODIR/$project (this may take a while...)"

	# this call seems to update all languages from templates, except the templates itself
	# this leads to poor exports as exported template is wrong
	# for this reason, we call this on a per-language basis
	read_pootle_projects_and_locales

	# TODO: see what happens when units have OBSOLETE status (-100)
	for locale in "${POOTLE_PROJECT_LOCALES[@]}"; do
		storeId=$(get_store_id $project $locale)
		template_length=$(count_keys "$PODIR/$project/${FILE}.$PROP_EXT")
		while : ; do
			call_manage "update_from_templates" "--project=$project" "--language=$locale" "-v 0"
			store_unit_count=$(count_targets $storeId)
			logt 4 "Language file has $template_length keys. Store $storeId has $store_unit_count keys"
		 	#[[ $template_length > $store_unit_count ]] || break
		 	# allow the store to have one key more or less than the incoming template
			(( store_unit_count <= template_length + 1 )) && (( store_unit_count >= template_length - 1 )) && break;
		 	[[ "$locale" == "sr_RS_latin" ]] && break
		done
	done;

	start_pootle_session

	logt 3 -n "Telling pootle to rescan template file"
	status_code=$(curl $CURL_OPTS -m 120 -w "%{http_code}" -d "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" -d "scan_files=Rescan project files" "$PO_SRV/templates/$project/admin_files.html" 2> /dev/null)
	[[ $status_code == "200" ]]
	check_command

	# due to we disabled the update translations flag in update_from_templates, at this point we have the right english texts only in the templates store.
	# it's time to distribute it across all stores
	storeId=$(get_store_id $project "templates")
	get_keys_by_store "$storeId"

	logt 3 "Updating source texts from ${#unitids_by_store[@]} keys in store $storeId"
	update_source_sql="$TMP_PROP_IN_DIR/update_source_data_from_template.sql"
	rm -Rf $update_source_sql >/dev/null 2>&1
	for key in "${unitids_by_store[@]}"; do
		log -n " $key"
		batch_update_source_data_from_template "$storeId" "$key" "$update_source_sql"
	done
	log
	runSQL "$update_source_sql"

	logt 3 "Rebuilding indexes"
	sort_indexes $storeId
	for locale in "${POOTLE_PROJECT_LOCALES[@]}"; do
		storeId=$(get_store_id $project $locale)
		sort_indexes $storeId
	done
	log

	logt 3 "Resurrecting obsolete units"
	logt 4 -n "Setting empty units as untranslated"
	update_obsolete_empty_units
	check_command
	logt 4 -n "Setting non empty units as fuzzy"
	update_obsolete_nonempty_units
	check_command
}

function update_pootle_db_from_templates() {
	logt 1 "Updating pootle database from repository-based project set ..."

	check_dir "$PODIR/$POOTLE_PROJECT_ID/"
	rm -f $PODIR/$POOTLE_PROJECT_ID/$FILE.$PROP_EXT 2>&1

	logt 2 "Pootle $POOTLE_PROJECT_ID: will update templates from ${#AP_PROJECT_NAMES[@]} projects"

	logt 3 "Combining templates of  ${#AP_PROJECT_NAMES[@]} into a single file"
	for source_code_project in "${!AP_PROJECT_NAMES[@]}"; do
		logt 4 -n "Adding $source_code_project template"
		cat ${AP_PROJECT_SRC_LANG_BASE[$source_code_project]}/$FILE.$PROP_EXT >> $PODIR/$POOTLE_PROJECT_ID/$FILE.$PROP_EXT
		echo >> $PODIR/$POOTLE_PROJECT_ID/$FILE.$PROP_EXT
		check_command
	done

	update_from_templates $POOTLE_PROJECT_ID $PODIR/$POOTLE_PROJECT_ID
}
