function restore_backup_action() {
	backup_dir="$1"
	base_dir=$(echo "$backup_dir" | cut -d "-" -f 1-2)
	dumpfilename="pootle.sql"
	bzippeddumpfilename="pootle.sql.bz2"
	dumpfilepath="$TMP_DB_BACKUP_DIR/$base_dir/$backup_dir/$dumpfilename";
	bzippeddumpfilepath="$TMP_DB_BACKUP_DIR/$base_dir/$backup_dir/$bzippeddumpfilename";
	fsfilename="po.tgz"
	fsfilepath="$TMP_DB_BACKUP_DIR/$base_dir/$backup_dir/$fsfilename";

	if is_pootle_server_up; then
		logt 1 "Unable to restore backup as Pootle server is running. Please stop the server and rerun this action"
	elif [[ ! -f $bzippeddumpfilepath ]] || [[ ! -f $fsfilepath ]]; then
		logt 1 "Can't find backup files $bzippeddumpfilepath and/or $fsfilepath. Check backup ID $backup_dir"
	else
		logt 1  "Restoring pootle data from backup ID: $backup_dir"
		logt 2  "Restoring pootle database"
		logt 3 -n "Decompressing db dump";
		bunzip2 -k $bzippeddumpfilepath > /dev/null 2>&1;
		check_command;

		clean_tables
		logt 3 -n "Restoring DB dump";
		cat $dumpfilepath | $MYSQL_COMMAND $DB_NAME
		check_command;

		logt 2  "Restoring pootle filesystem"
		clean_dir $PODIR
		logt 3 -n "Decompressing filesystem backup"
		tar xf $fsfilepath -C $PODIR > /dev/null 2>&1;
		check_command;

		logt 2 "Cleaning files"
		rm $dumpfilepath;
	fi;
}