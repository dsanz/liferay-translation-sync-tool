declare -xgr lang_file_path_tail="src/content/Language.properties"
declare -xgr web_layout_prefix="docroot/WEB-INF"

declare -xgr web_layout_project_code_regex="/([^/]+)/$web_layout_prefix/$lang_file_path_tail"
declare -xgr std_layout_project_code_regex="/([^/]+)/$lang_file_path_tail"

declare -xgr traditional_plugin_regex="/([^/]+)$web_layout_project_code_regex"
declare -xgr generic_project_regex="/([^/]+)$std_layout_project_code_regex"
declare -xgr osgi_web_module_regex="modules/([^/]+)/([^/]+)$web_layout_project_code_regex"
declare -xgr osgi_module_regex="modules/([^/]+)/([^/]+)$std_layout_project_code_regex"

function get_project_code_from_path() {
	filepath="$1"
	type="none"

	if [[ $filepath == *"$web_layout_prefix"* ]]; then
		# project has the "web-layout" (<code>/docroot/WEB-INF/src/content/Language.properties)
		[[ $filepath =~ $web_layout_project_code_regex ]] ;
		projectCode="${BASH_REMATCH[1]}"

		# project can either be a traditional plugin or a osgi (web) module
		if [[ $filepath =~ $osgi_web_module_regex ]] ;
		then
			# project is an osgi web module
			projectFamily="${BASH_REMATCH[2]}"
			type="OSGi web module"
		else
			# project is a traditional liferay plugin
			[[ $filepath =~ $traditional_plugin_regex ]] ;
			projectFamily="${BASH_REMATCH[1]}"
			type="Liferay plugin"
		fi;
	else
		# project has standard layout.
		[[ $filepath =~ $std_layout_project_code_regex ]];
		projectCode="${BASH_REMATCH[1]}"

		# project can either be the portal or a osgi module
		if [[ $filepath =~ $osgi_module_regex ]] ;
			then
				# project is an osgi module
				projectFamily="${BASH_REMATCH[2]}"
				type="OSGi module"
			else
				# project is generic (e.g. portal, AT rules...)
				[[ $filepath =~ $generic_project_regex ]] ;
				projectFamily="${BASH_REMATCH[1]}"
				type="Generic"
		fi;
	fi
	logt 3 "Code: $projectCode, Family: $projectFamily, type: $type"
	logt 4 "$filepath"
}

function display_projects_from_source() {
	logt 1 "Calculating project list from current sources"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		logt 2 "$base_src_dir"
		for lang_file in $(find  $base_src_dir -wholename *"$lang_file_path_tail"); do
			get_project_code_from_path "$lang_file"
		done;
	done;
}

### DEPRECATED (just initial tests)

# this works for liferay (traditional) plugins and some osgi modules
function get_projects_web_layout() {
	base="$1"
	web_layout_count=0
	for f in $(find  $base -wholename *"$web_layout_file_regex"); do
		[[ $f =~ $web_project_code_regex ]];
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
	for f in $(find $base -wholename *"$std_layout_file_regex"); do
		if [[ $f != *"$web_layout_prefix"* ]];
		then
			[[ $f =~ $std_project_code_regex ]];
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
	translatable_count=$(find $base -wholename "$std_layout_file_regex" | wc -l)
	logt 4 "find $base -wholename \"$std_layout_file_regex\" | wc -l"
	logt 3 "Found $translatable_count translatable projects"
}

