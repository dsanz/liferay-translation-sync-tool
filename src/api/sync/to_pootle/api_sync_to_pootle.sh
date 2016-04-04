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
