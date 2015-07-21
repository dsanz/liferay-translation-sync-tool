# declare variables prefixed with AP_ which will be the "Auto Provisioned" counterparts for the master lists
# GIT_ROOTS and PR_EVIEWER are the unique variables which will be given to the tool.

# contains all project code names, as seen by pootle and source dirs
declare -xgA AP_PROJECT_NAMES
# contains an entry for each project, storing the project base source dir where Language.properties files are
declare -xgA AP_PROJECT_SRC_LANG_BASE
# contains an entry for each project, storing the ant dir where build-lang target is to be invoked
declare -xgA AP_PROJECT_ANT_BUILD_LANG_DIR
# contains an entry for each different base source dir, storing the list of
# projects associated with that dir
declare -xgA AP_PROJECTS_BY_GIT_ROOT

## some regex and patterns for project detection
declare -xgr lang_file_path_tail="src/content/Language.properties"
declare -xgr web_layout_prefix="docroot/WEB-INF"

declare -xgr web_layout_project_code_regex="/([^/]+)/$web_layout_prefix/$lang_file_path_tail"
declare -xgr std_layout_project_code_regex="/([^/]+)/$lang_file_path_tail"

declare -xgr traditional_plugin_regex="/([^/]+)$web_layout_project_code_regex"
declare -xgr generic_project_regex="/([^/]+)$std_layout_project_code_regex"
declare -xgr osgi_web_module_regex="modules/([^/]+)/([^/]+)$web_layout_project_code_regex"
declare -xgr osgi_module_regex="modules/([^/]+)/([^/]+)$std_layout_project_code_regex"

function prettify_name() {
	name="$1"
	r="";
	while read l; do
		r="$r ${l^}";
	done <<< "$(echo $name | tr '-' '\n')" ;

	echo $r
}

function read_project_from_path() {
	base_src_dir="$1"
	filepath="$2"
	type="none"

	if [[ $filepath == *"$web_layout_prefix"* ]]; then
		# project has the "web-layout" (<code>/docroot/WEB-INF/src/content/Language.properties)
		[[ $filepath =~ $web_layout_project_code_regex ]] ;
		project_code="${BASH_REMATCH[1]}"

		# project can either be a traditional plugin or a osgi (web) module
		if [[ $filepath =~ $osgi_web_module_regex ]] ;
		then
			# project is an osgi web module
			project_family="${BASH_REMATCH[2]}"
			type="OSGi web module"
		else
			# project is a traditional liferay plugin
			[[ $filepath =~ $traditional_plugin_regex ]] ;
			project_family="${BASH_REMATCH[1]}"
			type="Liferay plugin"
		fi;
	else
		# project has standard layout.
		[[ $filepath =~ $std_layout_project_code_regex ]];
		project_code="${BASH_REMATCH[1]}"

		# project can either be the portal or a osgi module
		if [[ $filepath =~ $osgi_module_regex ]] ;
			then
				# project is an osgi module
				project_family="${BASH_REMATCH[2]}"
				type="OSGi module"
			else
				# project is generic (e.g. portal, AT rules...)
				[[ $filepath =~ $generic_project_regex ]] ;
				project_family="${BASH_REMATCH[1]}"
				type="Generic"
		fi;
	fi
	lang_rel_path=$filepath
	lang_rel_path=${lang_rel_path#$base_src_dir}
	lang_rel_path=${lang_rel_path%/Language.properties}

	project_name="$(prettify_name $project_family)/$(prettify_name $project_code)"

	log -n "."
	# for the auto-provisioner, ant build-lang dir will be invoked from the base src dir-
	add_AP_project "$project_code" "$project_name" "$base_src_dir" "$lang_rel_path"
}

# Adds a new Auto-provisioned project to the project arrays. Requires 4 parameters
#  - project code (eg "sibboleth-hook")
#  - project name (eg "Hooks/Shibboleth Hook")
#  - git_root_dir: root of source code for that project
#  - lang rel path: path where Language.properties file lives, relative to $2
#  - ant rel path: path where ant build-lang has to be invoked, relative to $2
function add_AP_project() {
	project_code="$1"
	project_name="$2"
	git_root_dir="$3"
	lang_rel_path="$4"
	ant_rel_path="$5"

	AP_PROJECT_NAMES["$project_code"]="$project_name"
	AP_PROJECT_SRC_LANG_BASE["$project_code"]="$git_root_dir$lang_rel_path"
	AP_PROJECT_ANT_BUILD_LANG_DIR["$project_code"]="$git_root_dir$ant_rel_path"
	AP_PROJECTS_BY_GIT_ROOT["$git_root_dir"]=" $project_code"${AP_PROJECTS_BY_GIT_ROOT["$git_root_dir"]}
}

function display_AP_projects() {
	logt 1 "(Auto Provisioned) Working project list by git root (${#AP_PROJECT_NAMES[@]} projects, ${#GIT_ROOTS[@]} git roots) "
	for git_root in "${!GIT_ROOTS[@]}"; do
		project_list="$(echo ${AP_PROJECTS_BY_GIT_ROOT["$git_root"]} | sed 's: :\n:g' | sort)"
		projects=$(echo "$project_list" | wc -l)
		logt 2 "Git root: $git_root ($projects projects). Sync branch: ${GIT_ROOTS[$git_root]}. Reviewer: ${PR_REVIEWER[$git_root]}"
		loglc 6 $RED "$(printf "%-40s%s" "Project Code")$(printf "%-85s%s" "Source dir (relative to $git_root)")$(printf "%-65s%s" "Project name")$(printf "%-5s%s" "Check") "
		while read project; do
			 logt 3 -n "$(printf "%-40s%s" "$project")"
			 project_src="${AP_PROJECT_SRC_LANG_BASE["$project"]}"
			 log -n "$(printf "%-85s%s" "${project_src#$git_root}")"
			 project_name="${AP_PROJECT_NAMES[$project]}"
			 log -n "$(printf "%-65s%s" "$project_name")"
			 [ -d $project_src ]
			 check_command
		done <<< "$project_list"
	done;
}

function read_projects_from_sources() {
	logt 1 "Calculating project list from current sources"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		logt 2 -n "$base_src_dir"
		for lang_file in $(find  $base_src_dir -wholename *"$lang_file_path_tail"); do
			read_project_from_path "$base_src_dir" "$lang_file"
		done;
		check_command
	done;
}