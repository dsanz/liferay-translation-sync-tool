function create_backup_action() {
	if [[ "${DO_BACKUPS}x" != "1x" ]]; then
		logt 1 "Not creating backup. Please set DO_BACKUPS env variable to \"1\" to do them."
		return;
	fi;

	logt 1  "Backing up pootle data..."
	base_dir=$(date +%Y-%m);
	backup_dir=$(date +%F_%H-%M-%S)
	dumpfilename="pootle.sql"
	dumpfilepath="$TMP_DB_BACKUP_DIR/$base_dir/$backup_dir/$dumpfilename";
	fsfilename="po.tgz"
	fsfilepath="$TMP_DB_BACKUP_DIR/$base_dir/$backup_dir/$fsfilename";
	check_dir "$TMP_DB_BACKUP_DIR/$base_dir/$backup_dir"

	logt 2 "Dumping Pootle DB into $dumpfilepath"
	logt 3 -n "Running dump command ";
	$MYSQL_DUMP_COMMAND $DB_NAME > $dumpfilepath;
	check_command;

	logt 3 -n "Compressing db dump";
	bzip2 $dumpfilepath > /dev/null 2>&1;
	check_command;

	logt 2 "Compressing po/ dir into $fsfilepath"
	logt 3 -n "Running tar command: tar czvf $fsfilepath $PODIR";
	old_pwd=$(pwd)
	cd $PODIR
	tar czvf $fsfilepath * > /dev/null 2>&1;
	cd $old_pwd
	check_command;

	logt 2 "Backup ID: $backup_dir"
}
