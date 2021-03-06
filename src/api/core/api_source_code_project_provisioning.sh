## some regex and patterns for project detection

# regex for Language.properties final path. Since LPS-59564 we have to support 2 possible file layouts.
# Prior to LPS-59664, this was a pattern. Now is a regex so we can't use it as a constant. We
# have to match some string against it and use the match to process relevant paths
declare -xgr lang_file_path_tail="src/(main/resources/)?content/Language.properties"

# this allows us to know we are in a web.like project: portlet, web-osgi module,...
declare -xgr web_layout_prefix="docroot/WEB-INF"

# these capture the project code from the 2 different file layouts
declare -xgr web_layout_project_code_regex="/([^/]+)/$web_layout_prefix/($lang_file_path_tail)"
declare -xgr std_layout_project_code_regex="/([^/]+)/($lang_file_path_tail)"

# finally, these capture whole project types from the very git root dir
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
	type="unknown"
	project_family="unknown"

	# relative path where invoke build-lang target
	build_lang_rel_path=${filepath#$base_src_dir}

	if [[ $filepath == *"$web_layout_prefix"* ]]; then
		# project has the "web-layout" (<code>/docroot/WEB-INF/$lang_file_path_tail)
		[[ $filepath =~ $web_layout_project_code_regex ]] ;
		# get project code and actual lang file location within the project
		project_code="${BASH_REMATCH[1]}"
		lang_file_tail="${BASH_REMATCH[2]}"

		# for these projects, ant build-lang is invoked from the plugin itself
		build_lang_rel_path=${build_lang_rel_path%$web_layout_prefix/$lang_file_tail}

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
		# project has standard layout (<code>/$lang_file_path_tail)
		[[ $filepath =~ $std_layout_project_code_regex ]];
		# get project code and actual lang file location within the project
		project_code="${BASH_REMATCH[1]}"
		lang_file_tail="${BASH_REMATCH[2]}"

		# for these projects, build-lang is invoked from the base dir, like plugins
		build_lang_rel_path=${build_lang_rel_path%$lang_file_tail}

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

	logt 4 "Found $type project $project_code '$project_name' (family: $project_family)"
	# for the auto-provisioner, ant build-lang dir will be invoked from the base src dir-
	add_AP_project "$project_code" "$project_name" "$base_src_dir" "$lang_rel_path" "$build_lang_rel_path"
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
	build_lang_rel_path="$5"

	AP_PROJECT_NAMES["$project_code"]="$project_name"
	AP_PROJECT_GIT_ROOT["$project_code"]="$git_root_dir"
	AP_PROJECT_SRC_LANG_BASE["$project_code"]="$git_root_dir$lang_rel_path"
	AP_PROJECT_BUILD_LANG_DIR["$project_code"]="$git_root_dir$build_lang_rel_path"
	AP_PROJECTS_BY_GIT_ROOT["$git_root_dir"]=" $project_code"${AP_PROJECTS_BY_GIT_ROOT["$git_root_dir"]}
}

function read_projects_from_sources() {
	pull_source_code
	logt 1 "Calculating project list from current sources"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		logt 2 "$base_src_dir"
		for lang_file in $(find  $base_src_dir -regextype posix-extended -regex ".*/$lang_file_path_tail"); do
			if is_path_blacklisted $lang_file; then
				logt 3 "Blacklisted: $lang_file"
			else
				read_project_from_path "$base_src_dir" "$lang_file"
			fi;
		done;
		check_command
	done;
}

function is_path_blacklisted() {
	lang_path="$1"
	blacklisted=false
	for regex in "${POOTLE_PROJECT_PATH_BLACKLIST_REGEXS[@]}";
	do
		if [[ "$lang_path" =~ $regex ]]; then
			blacklisted=true;
			break;
		fi;
	done;
	[ "$blacklisted" = true ]
}

function get_repository_name() {
	git_root_dir="$1"
	cd $git_root_dir

	echo $(git remote show -n upstream | grep Fetch | sed -r 's:(([^/]*/)?+)([^\.]+)\.git:\3:g')
}

function add_git_root() {
	git_root_dir="$1"
	pr_reviewer="$2"
	sync_branch="$3"

	[[ "$pr_reviewer" == "" ]] && pr_reviewer=$DEFAULT_PR_REVIEWER;
	[[ "$sync_branch" == "" ]] && sync_branch=$DEFAULT_SYNC_BRANCH;

	pootle_project_name="$(get_repository_name $git_root_dir)"

	GIT_ROOT_POOTLE_PROJECT_NAME["$git_root_dir"]=$pootle_project_name
	GIT_ROOTS["$git_root_dir"]=$sync_branch;
	PR_REVIEWER["$git_root_dir"]=$pr_reviewer;
}