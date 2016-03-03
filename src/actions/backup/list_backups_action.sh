function list_backups_action() {
	logt 1 "Available backups"

	for month in $(ls $TMP_DB_BACKUP_DIR/); do
		logt 2 "From $month"
		for backup_id in $(ls $TMP_DB_BACKUP_DIR/$month); do
			logt 3 "Backup ID: $backup_id"
			for backup_file in $(ls $TMP_DB_BACKUP_DIR/$month/$backup_id); do
				logt 4 "$(ls $TMP_DB_BACKUP_DIR/$month/$backup_id/$backup_file -lag)"
			done;
		done;
	done;
}
