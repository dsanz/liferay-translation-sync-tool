function upload_derived_translations_action() {
	project="$1"
	derived_locale="$2"
	parent_locale="$3"
	loglc 1 $RED  "Uploading $derived_locale (derived language) translations for project $project"
	create_backup_action
	post_derived_translations $project $derived_locale $parent_locale
	loglc 1 $RED "Upload finished"
}