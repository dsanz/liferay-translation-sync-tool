function add_git_root() {
	git_root_dir=$1
	pr_reviewer=$2

	GIT_ROOTS["$git_root_dir"]=$git_root_dir;
	PR_REVIEWER["$git_root_dir"]=$pr_reviewer;
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
	PATH_BASE_DIR["$git_root_dir"]="$git_root_dir"
	PATH_PROJECTS["$git_root_dir"]=" $project_name"${PATH_PROJECTS["$git_root_dir"]}
}

# adds a bunch of projects to the project arrays. This function is specific for
# adding liferay plugins stored in the same git repo. Requires 4 parameters:
#  - project names list: a space-separated string of project names, w/o suffix
#  - type: indicate the Liferay plugin type ("hook", "portlet", "theme")
#  - git_root_dir: root of source code for the plugins SDK/repo
#  - lang_rel_path: path where Language.properties file lives (relative to ${3}/project_rel_path/project_name).
#  - [optional] project_rel_path: relative to $3, indicates the dir where project is stored. If not specified, Liferay SDK dir layout will be used
# Function will compute the actual paths for each individual project as they are laid out in a SDK/plugins git repo
function add_projects_Liferay_plugins() {
	project_names="$1"
	type="$2"
	project_type="-$type"


	if [ -z ${5+x} ]; then
		# project_rel_path has not been passed, use the type
		project_rel_path_fragment="${type}s/";
	else
		# project_rel_path has been passed. Check if it's empty
		project_rel_path_fragment="$5";
		if [[ $5 != "" ]]; then
			project_rel_path_fragment="${5}/";
		fi;
	fi;


	git_root_dir="$3"
	lang_rel_path_fragment="$4"

	for name in $project_names;
	do
		# project name is made up from the name + project_type (eg "mail" + "-portlet")
		project_name="$name$project_type"
		# project base path locates the project inside git_root_dir (e.g "portlets/mail-portlet/")
		project_base_path="$project_rel_path_fragment${project_name}/"
		# ant path is assumed to be the project base path. Works for our SDK plugins
		# lang_rel_path is prefixed with the project dir
		lang_rel_path="$project_base_path$lang_rel_path_fragment"
		add_project "$project_name" "${git_root_dir}" "$lang_rel_path" "$project_base_path"
	done
}

# adds a bunch of projects to the project arrays. This function is generic and allows to
# add any project set stored in the same git repo. Requires 3 parameters:
#  - project names list: a space-separated string of project names, w/o suffix
#  - git_root_dir: root of source code for the plugins SDK/repo
#  - lang_rel_path: path where Language.properties file lives (relative to ${2}/).
# Function assumes thst ant path is the root of each project
function add_projects() {
	project_names="$1"
	git_root_dir="$2"
	lang_rel_path_fragment="$3"

	for project_name in $project_names;
	do
		# project base path locates the project inside git_root_dir (e.g "portlets/mail-portlet/")
		project_base_path="$project_rel_path_fragment${project_name}/"
		# ant path is assumed to be the project base path. Works for our SDK plugins
		# lang_rel_path is prefixed with the project dir
		lang_rel_path="$project_name/$lang_rel_path_fragment"
		add_project "$project_name" "${git_root_dir}" "$lang_rel_path" "$project_name"
	done
}
