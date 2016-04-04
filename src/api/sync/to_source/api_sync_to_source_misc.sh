function prepare_output_dir() {
	project="$1"
	logt 2 "$project: cleaning output working dirs"
	clean_dir "$TMP_PROP_OUT_DIR/$project"
}

# creates temporary working dirs for working with pootle output
function clean_temp_output_dirs() {
	logt 1 "Preparing project output working dirs..."
	logt 2 "Cleaning general output working dirs"
	clean_dir "$TMP_PROP_OUT_DIR/"
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		prepare_output_dir "$project"
	done
}
