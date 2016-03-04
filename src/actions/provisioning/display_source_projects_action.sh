function display_source_projects_action() {
	read_projects_from_sources
	logt 1 "(Auto Provisioned) Working project list by git root (${#AP_PROJECT_NAMES[@]} projects, ${#GIT_ROOTS[@]} git roots) "
	for git_root in "${!GIT_ROOTS[@]}"; do
		project_list="$(echo ${AP_PROJECTS_BY_GIT_ROOT["$git_root"]} | sed 's: :\n:g' | sort)"
		projects=$(echo "$project_list" | wc -l)
		logt 2 "Git root: $git_root ($projects projects). Sync branch: ${GIT_ROOTS[$git_root]}. Reviewer: ${PR_REVIEWER[$git_root]}. Repo project name: ${GIT_ROOT_POOTLE_PROJECT_NAME[$git_root]}"
		logc $RED "$(printf "%-51s%s" "Project Code")$(printf "%-100s%s" "Build-lang path (relative to git_root)")$(printf "%-35s%s" "Lang file base (rel to build lang)")$(printf "%-60s%s" "Project name")$(printf "%-5s%s" "Check") "
		while read project; do
			log -n "$(printf "%-51s%s" "$project")"
			build_lang_path="${AP_PROJECT_BUILD_LANG_DIR[$project]}"
			build_lang_path="${build_lang_path#$git_root}"
			log -n "$(printf "%-100s%s" "$build_lang_path")"
			src_lang_base="${AP_PROJECT_SRC_LANG_BASE[$project]}"
			src_lang_base="${src_lang_base#$git_root}"
			src_lang_base="${src_lang_base#$build_lang_path}"
			log -n "$(printf "%-35s%s" "$src_lang_base")"
			project_name="${AP_PROJECT_NAMES[$project]}"
			log -n "$(printf "%-60s%s" "$project_name")"
			[ -d ${AP_PROJECT_SRC_LANG_BASE[$project]} ]
			check_command
		done <<< "$project_list"
		log
	done;
}

