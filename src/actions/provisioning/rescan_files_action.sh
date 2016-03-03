function rescan_files_action() {
	backup_db
	logt 1 "Uniformizing wrong pootle paths"
	fix_malformed_paths_having_dashes
	fix_malformed_paths_gnu
}
