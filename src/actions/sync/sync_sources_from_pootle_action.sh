function sync_sources_from_pootle_action() {
	read_projects_from_sources
	if [ $SYNC_POOTLE ]; then
		src2pootle
	fi
	pootle2src
}
