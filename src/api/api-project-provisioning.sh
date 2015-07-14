# declare variables prefixed with AP_ which will be the "Auto Provisioned" counterparts for the master lists
# GIT_ROOTS is the unique variable which will be given to the tool.

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

function get_project_code_from_path() {
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
	logt 3 "Code: $project_code, Family: $project_family, type: $type, name: $project_name"
	logt 4 "$filepath"
	logt 4 "$lang_rel_path"

	add_AP_project "$project_code" "$project_family/$project_code" "$base_src_dir" "$lang_rel_path" "test"
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
	AP_PROJECT_SRC_LANG_BASE["$project_name"]="$git_root_dir$lang_rel_path"
	AP_PROJECT_ANT_BUILD_LANG_DIR["$project_name"]="$git_root_dir$ant_rel_path"
	AP_PROJECTS_BY_GIT_ROOT["$git_root_dir"]=" $project_name"${AP_PROJECTS_BY_GIT_ROOT["$git_root_dir"]}
}

function display_AP_projects() {
	logt 1 "Calculating project list from current sources"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		logt 2 "$base_src_dir"
		for lang_file in $(find  $base_src_dir -wholename *"$lang_file_path_tail"); do
			get_project_code_from_path "$base_src_dir" "$lang_file"
		done;
	done;

	logt 1 "(Auto Provisioned) Working project list by git root (${#AP_PROJECT_NAMES[@]} projects, ${#GIT_ROOTS[@]} git roots) "
	for git_root in "${!GIT_ROOTS[@]}"; do
		project_list="$(echo ${AP_PROJECTS_BY_GIT_ROOT["$git_root"]} | sed 's: :\n:g' | sort)"
		projects=$(echo "$project_list" | wc -l)
		logt 2 "Git root: $git_root ($projects projects). Sync branch: ${GIT_ROOTS[$git_root]}. Reviewer: ${PR_REVIEWER[$git_root]}"
		while read project; do
			logt 3 -n "$(printf "%-35s%s" "$project")"
			project_src="${AP_PROJECT_SRC_LANG_BASE["$project"]}"
			log -n $project_src
			[ -d $project_src ]
			check_command
		done <<< "$project_list"
	done;
}

# Adds a new project to the project arrays. Requires 4 parameters
#  - project name (eg "sibboleth-hook")
#  - git_root_dir: root of source code for that project
#  - lang rel path: path where Language.properties file lives, relative to $2
#  - ant rel path: path where ant build-lang has to be invoked, relative to $2
function add_project() {
	project_name="$1"
	git_root_dir="$2"
	lang_rel_path="$3"
	ant_rel_path="$4"

	PROJECT_NAMES["$project_name"]="$project_name"
	PROJECT_SRC_LANG_BASE["$project_name"]="$git_root_dir$lang_rel_path"
	PROJECT_ANT_BUILD_LANG_DIR["$project_name"]="$git_root_dir$ant_rel_path"
	PROJECTS_BY_GIT_ROOT["$git_root_dir"]=" $project_name"${PROJECTS_BY_GIT_ROOT["$git_root_dir"]}
}


### DEPRECATED (just initial tests)

# this works for liferay (traditional) plugins and some osgi modules
function get_projects_web_layout() {
	base="$1"
	web_layout_count=0
	for f in $(find  $base -wholename *"$web_layout_file_regex"); do
		[[ $f =~ $web_project_code_regex ]];
		project_code="${BASH_REMATCH[1]}"
		if [[ $project_code != "" ]];
		then
			logt 3 "Web layout: $project_code ($f)";
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
			project_code="${BASH_REMATCH[1]}"
			if [[ $project_code != "" ]];
			then
				logt 3 "Std layout: $project_code ($f)";
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

