function backport_all_action() {
	loglc 1 $RED "Begin backport process"
	display_projects

	use_git=0
	do_commit=0
	source_branch="$1"
	target_branch="$2"

	# prepare git for all base-paths
	logt 1 "Preparing involved directories"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		check_git "$base_src_dir" "$(get_ee_target_dir $base_src_dir)" "$source_branch" "$target_branch"
	done

	# backport is done on a project basis
	logt 1 "Backporting"
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		logt 2 "$project"
		source_dir="${AP_PROJECT_SRC_LANG_BASE["$project"]}"
		target_dir=$(get_ee_target_dir $source_dir)
		backport_project "$project" "$source_dir" "$target_dir"
	done;

	# commit result is again done on a base-path basis
	logt 1 "Committing backport process results"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		commit_result  "$base_src_dir" "$(get_ee_target_dir $base_src_dir)"
	done

	loglc 1 $RED "End backport process"
}
