function check_quality_action() {
	loglc 1 $RED "Begin Quality Checks"
	display_source_projects_action
	clean_temp_output_dirs
	export_pootle_translations_to_temp_dirs
	ascii_2_native
	run_quality_checks
	loglc 1 $RED "End Quality Checks"
}