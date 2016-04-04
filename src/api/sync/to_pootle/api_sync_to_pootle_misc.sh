
function refresh_stats_repo_based() {
	logt 1 "Refreshing Pootle stats..."
	for project in "${GIT_ROOT_POOTLE_PROJECT_NAME[@]}"; do
		refresh_project_stats $project
	done
}

function refresh_project_stats() {
	project="$1"

	logt 2 "$project: refreshing stats"
	call_manage "refresh_stats" "--project=$project" "-v 0"
}

function clean_temp_input_dirs() {
	logt 1 "Preparing project input working dirs..."
	logt 2 "Cleaning general input working dir"
	clean_dir "$TMP_PROP_IN_DIR/"
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		logt 2 "$project: cleaning input working dirs"
		clean_dir "$TMP_PROP_IN_DIR/$project"
	done
}