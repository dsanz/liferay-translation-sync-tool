#!/bin/bash

####
## Get parameter
####
# $1 - Which parameter would you like to get
# $2 - Get parameter from this list (usually something like ${PROJECTS[$i]})
function get_param() {
	shift $1
	echo  $1
}

####
## Verify parameters
####
# $1 - How many parameters should be passed on, otherwise fail...
# $2 - Message to be displayed if verification failed
# $* - Parameters to be verified
function verify_params() {
	[ "$#" -lt $(($1 + 2)) ] && echo_red "$2" && exit 1
}

# Given a project, returns the root dir where sources are supposed to be
function get_src_base_dir() {
	project="$1"
	if [[ $project == $PORTAL_PROJECT_ID ]]; then
		result=$SRC_PORTAL_BASE;
	else
		result=$SRC_PLUGINS_BASE;
	fi;
	echo $result
}

function add_base_path() {
	project=$1
	base_src_dir=$2
	idx=-1;
	local j;
	for (( j=0; j<${#PATH_BASE_DIR[@]}; j++ ));
	do
		if [[ "${PATH_BASE_DIR[$j]}" == "$base_src_dir" ]]; then
			idx=$j;
		fi;
	done;
	if [[ $idx == -1 ]]; then
		idx=${#PATH_BASE_DIR[@]};
	fi;
	PATH_BASE_DIR[$idx]="$base_src_dir"
	PATH_PROJECTS[$idx]=" $project"${PATH_PROJECTS[$idx]}
}

function compute_working_paths() {
	local i;
	for (( i=0; i<${#PROJECT_NAMES[@]}; i++ ));
	do
		add_base_path "${PROJECT_NAMES[$i]}" "$(get_src_base_dir ${PROJECT_NAMES[$i]})"
	done
}

function get_project_language_path() {
	project="$1"
	local j;
	for (( j=0; j<${#PROJECT_NAMES[@]}; j++ ));
	do
		if [[ "${PROJECT_NAMES[$j]}" == "$project" ]]; then
			idx=$j;
		fi;
	done;
	if [[ $idx == -1 ]]; then
		result=""
	else
		result="${PROJECT_SRC[$idx]}";
	fi;
	echo "$result"
}

function add_project() {
	project_name="$1"
	source_path="$2"

	PROJECT_NAMES[${#PROJECT_NAMES[@]}]="$project_name"
	PROJECT_SRC[${#PROJECT_SRC[@]}]="$source_path"
}

function add_projects() {
	plugins="$1"
	suffix="$2"
	prefix="$3"

	for plugin in $plugins;
	do
		pootle_project_id="$plugin$suffix"
		add_project "$pootle_project_id" "${prefix}${pootle_project_id}${SRC_PLUGINS_LANG_PATH}"
	done
}

# $1 - This parameter must contain $@ (parameters to resolve).
function resolve_params() {
	params="$@"
	[ "$params" = "" ] && export HELP=1
	for param in $params ; do
		if [ "$param" = "--pootle2repo" ] || [ "$param" = "-r" ]; then
			export UPDATE_REPOSITORY=1
		elif [ "$param" = "--repo2pootle" ] || [ "$param" = "-p" ]; then
			export UPDATE_POOTLE_DB=1
		elif [ "$param" = "--help" ] && [ "$param" = "-h" ] && [ "$param" = "/?" ]; then
			export HELP=1
		else
			echo_red "PAY ATTENTION! You've used unknown parameter."
			any_key
		fi
	done
	if [ $HELP ]; then
		echo_white ".: Pootle Manager 1.9 :."
		echo
		echo "This is simple Pootle management tool that syncrhonizes the translations from VCS repository to pootle DB and vice-versa, taking into account automatic translations (which are uploaded as suggestions to pootle). Please, you should have configured variables in the script."
		echo "Arguments:"
		echo "  -r, --pootle2repo	Sync. stores of pootle and prepares files for commit to VCS (does not commit any file)"
		echo "  -p, --repo2pootle	Updates all language files from VCS repository and update Pootle database."
		echo

		UPDATE_REPOSITORY=
		UPDATE_POOTLE_DB=
	else
		echo_green "[`date`] Pootle manager [START]"
	fi
}

function load_config() {
	if [[ -n "$POOTLE_MANAGER_PROFILE" ]]; then
		pmp="pootle-manager.$POOTLE_MANAGER_PROFILE.conf.sh"
		echo_yellow "Loading configuration profile '$pmp'"
	else
		pmp="pootle-manager.conf.sh"
		echo_yellow "Loading default config profile '$pmp'"
	fi;

	. "conf/${pmp}"
}
