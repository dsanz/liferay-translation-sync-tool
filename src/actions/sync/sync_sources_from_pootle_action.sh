function sync_sources_from_pootle_action() {
	read_projects_from_sources
	if [ $UPDATE_POOTLE_DB ]; then
		src2pootle
	fi
	pootle2src
}
