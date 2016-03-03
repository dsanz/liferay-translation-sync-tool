function upload_translations_action() {
	loglc 1 $RED  "Uploading $2 translations for project $1"
	backup_db
	post_file $1 $2
	loglc 1 $RED "Upload finished"
}