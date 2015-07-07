
# this works for liferay (traditional) plugins and some osgi modules
function get_projects_web_layout() {
	base="$1"
	regex="/([^/]+)/docroot/WEB-INF/src";
	for f in $(find  $base -wholename "*/docroot/WEB-INF/src/content/Language.properties"); do
		logt 3 "Web layout: $f"
		[[ $f =~ $regex ]];
		projectCode="${BASH_REMATCH[1]}"
		if [[ $projectCode != "" ]];
		then
			logt 4 "Web layout: $projectCode --> $f";
		fi
	done
}

# this works for portal and most osgi modules
function get_projects_standard_layout() {
	base="$1"
	regex="/([^/]+)/docroot/WEB-INF/src";
	for f in $(find $base -wholename "*src/content/Language.properties"); do
		[[ $f =~ $regex ]];
		projectCode="${BASH_REMATCH[1]}"
		if [[ $projectCode != "" ]];
		then
			logt 4 "Std layout: $projectCode --> $f";
		fi
	done
}

function display_projects_from_source() {
	logt 1 "Calculating project list from current sources"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		logt 2 "$base_src_dir"
		get_projects_standard_layout "$base_src_dir"
		get_projects_web_layout "$base_src_dir"
	done;
}