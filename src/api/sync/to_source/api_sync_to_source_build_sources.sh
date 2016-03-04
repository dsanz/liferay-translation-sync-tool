function ant_all() {
	if [[ "${LR_TRANS_MGR_PROFILE}" == "dev" ]]; then
		logt 1 "Skipping ant all as we are in dev environment."
		return;
	fi;

	logt 1 "Running ant all for portal"
	logt 3 -n "cd $SRC_PORTAL_BASE"
	cd ${SRC_PORTAL_BASE}
	check_command
	ant_log_dir="$logbase/$PORTAL_PROJECT_ID"
	ant_log="$ant_log_dir/ant-all.log"
	check_dir $ant_log_dir
	logt 2 -n "$ANT_BIN all (all output redirected to $ant_log)"
	$ANT_BIN all > "$ant_log" 2>&1
	check_command
}

function build_lang() {
	ant_all
	logt 1 "Running ant build-lang"
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		ant_dir="${AP_PROJECT_BUILD_LANG_DIR[$project]}"
		logt 2 "$project"
		logt 3 -n "cd $ant_dir"
		cd $ant_dir
		check_command
		ant_log="$logbase/$project/ant-build-lang.log"
		logt 3 -n "$ANT_BIN build-lang (all output redirected to $ant_log)"
		$ANT_BIN build-lang > "$ant_log" 2>&1
		check_command

		# this checks if ant build-lang tell us to run gradlew buildLang
		logt 2 "Checking if ant redirects to gradle"
		invocation=$(cat "$ant_log" | grep "instead" | sed -r 's/[^:]+: (.*)$/\1/g')
		if [[ $invocation == *"gradle"* ]]; then
			gradle_log="$logbase/$project/gradle-build-lang.log"
			logt 3 "Running '$invocation' (all output redirected to $gradle_log)"
			$invocation > $gradle_log 2>&1
			check_command
		fi
	done;
}
