declare lang_file_path_tail="src/content/$FILE.$PROP_EXT"
declare web_layout_prefix="docroot/WEB-INF"
declare web_layout_file_pattern="*/$web_layout_prefix/$lang_file_path_tail"
declare std_layout_file_pattern="*/$lang_file_path_tail"
declare project_name_regex="/([^/]+)/docroot/WEB-INF/src"

# this works for liferay (traditional) plugins and some osgi modules
function get_projects_web_layout() {
	base="$1"
	web_layout_count=0
	for f in $(find  $base -wholename $web_layout_file_pattern); do
		[[ $f =~ $regex ]];
		projectCode="${BASH_REMATCH[1]}"
		if [[ $projectCode != "" ]];
		then
			logt 3 "Web layout: $projectCode ($f)";
			(( web_layout_count++ ))
		fi
	done
	logt 3 "Found $web_layout_count translatable projects using web file layout"
}

# this works for portal and most osgi modules
function get_projects_standard_layout() {
	base="$1"
	std_layout_count=0
	for f in $(find $base -wholename $std_layout_file_pattern ); do
		if [[ $f != *"$web_layout_prefix"* ]];
		then
			[[ $f =~ $regex ]];
			projectCode="${BASH_REMATCH[1]}"
			if [[ $projectCode != "" ]];
			then
				logt 3 "Std layout: $projectCode ($f)";
				(( std_layout_count++ ))
			fi
		fi
	done
	logt 3 "Found $std_layout_count translatable projects using standard file layout"
}

function count_translatable_projects() {
	base="$1"
	logt 3 "Found $(find $base -wholename $std_layout_file_pattern | wc -l) translatable projects"
}

function display_projects_from_source() {
	logt 1 "Calculating project list from current sources"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		logt 2 "$base_src_dir"
		count_translatable_projects "$base_src_dir"
		get_projects_standard_layout "$base_src_dir"
		get_projects_web_layout "$base_src_dir"
	done;
}