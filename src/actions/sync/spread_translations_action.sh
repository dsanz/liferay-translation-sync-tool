# spread translations from a source project to the other ones within the same branch
# source project translations will be exported from pootle into PODIR
# source project git root will be pulled from upstream
# then, source project translations from PODIR are backported into target projects
# the target projects are all projects sharing the same git_root with the source project
# result is committed
#
# $1 is the source project code
# $2 is the project list to which translations will be spread
function spread_translations_action() {
	read_projects_from_sources

	source_project="$1"
	project_list="$2"
	logt 1 "Preparing to spread translations from project $source_project"

	# try to get git root from source project first
	git_root="${AP_PROJECT_GIT_ROOT["$source_project"]}"
	# try to get source dir from auto-provisioned stuff indexing by source_project
	source_dir="${AP_PROJECT_SRC_LANG_BASE["$source_project"]}"

	# as source project might not exist in sources, let's check and try plan B instead
	# Plan B: get git root from destination project. In this case, destination project
	# has to be explicitly listed

	if [[ $project_list == "" && $git_root == "" ]]; then
		logc $RED "There is no way to compute git root dir. Please provide either an existing source project or specify a list of destination projects"
		return;
	fi;

    if [[ $git_root == "" ]]; then
		first_project="$(echo $project_list | cut -d " " -f1)"
		logt 2 "I can not compute git root. I'll use the git root of first destination project: $first_project"
		git_root="${AP_PROJECT_GIT_ROOT["$first_project"]}"
	fi;

	if [[ $project_list == "" ]]; then
		logt 2 "Source project does not exist in $git_root. I'll use all projects"
		project_list=${AP_PROJECTS_BY_GIT_ROOT["$git_root"]}
	fi;

	if [[ $source_dir == "" ]]; then
		logt 2 "Source project does not exist in $git_root. I'll create a temporary location for it "
		logt -n 4 "Creating $git_root/temp/$source_project"
		mkdir --parents "$git_root/temp/$source_project"
		check_command
		add_AP_project "$source_project" "$source_project" "$git_root" "temp/$source_project" "temp/$source_project"
		source_dir="${AP_PROJECT_SRC_LANG_BASE["$source_project"]}"
	fi;

	logt 2 "Translations will be spread as follows:"
	logt 3 "Source project: $source_project "
	logt 3 "Source dir: $source_dir "
	logt 3 "Destination project(s): $project_list  (Source project will be excluded from this list if exists)"
	logt 3 "Git root: $git_root"

	project_list="$(echo "$project_list" | sed 's: :\n:g' | sort)"

	# this will export all source project translations into $source_dir as we do in pootle2src, but only for source_project
	clean_temp_output_dirs
	read_pootle_projects_and_locales # we eed the set of locales to copy & process translated stuff from source project
	export_pootle_project_translations_to_temp_dirs $source_project
	process_project_translations $source_project false
	# don't forget to copy the Language.properties itself to the source dir. In a regular export this is not required.
	logt 2 -n "Copying language template from $source_project export to the source code"
	cp -f  "$PODIR/$project/${FILE}.$PROP_EXT" "$source_dir"
	check_command
	restore_file_ownership

	logt 1 "Source project has been exported. Now I will spread its translations to the other projects in $git_root"

	# iterate all projects in the destination project list and 'backport' to them
	while read target_project; do
		if [[ $target_project != $source_project ]]; then
			target_dir="${AP_PROJECT_SRC_LANG_BASE["$target_project"]}"
			# don't need further processing on pootle exported tranlations. The backporter will discard untranslated keys
			unset K
			unset T
			unset L;
			declare -gA T;
			declare -ga K;
			declare -ag L;
			backport_project "$source_project > $target_project" "$source_dir" "$target_dir"
		fi
	done <<< "$project_list"

	# commit_result function was designed for the backporter but can be used here
	# it must be called once as we are in just a single git root. Source project translations remain untouched.
	# before committing, lets revert source project changes. This way, just spread translations will be committed
	logt 2 "Resetting $source_project changes before committing"
	cd $source_dir
	for language_file in $(ls); do
		logt 3 -n "git checkout HEAD $language_file"
		git checkout HEAD $language_file;
		check_command
	done
	do_commit=0

	# tweak a bit the arrays expected by commit_result so that spread commit message makes sense.
	branch["$source_project"]="$source_project"
	commit["$source_project"]="pootle"
	cd $target_dir
	branch["$git_root"]="$target_project"
	commit["$git_root"]=$(git rev-parse HEAD)
	commit_result "$source_project" "$git_root"
}