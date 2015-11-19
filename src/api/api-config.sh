#!/bin/bash

# Get parameter
# $1 - Which parameter would you like to get
# $2 - Get parameter from this list (usually something like ${PROJECTS[$i]})
function get_param() {
	shift $1
	echo  $1
}

function get_locales_from_source() {
	project="$1"
	src_dir="${AP_PROJECT_SRC_LANG_BASE["$project"]}"
	echo $(ls -l $src_dir/Language_* | cut -f 1 -d . | cut -f 2- -d _)
}

# $1 - This parameter must contain $@ (parameters to resolve).
function resolve_params() {
	params="$@"
	[ "$params" = "" ] && export HELP=1
	for param in $1 ; do
		if [ "$param" = "--pootle2repo" ] || [ "$param" = "-r" ]; then
			export UPDATE_REPOSITORY=1
		elif [ "$param" = "--repo2pootle2repo" ] || [ "$param" = "-R" ]; then
			export UPDATE_POOTLE_DB=1
			export UPDATE_REPOSITORY=1
		elif [ "$param" = "--repo2pootle" ] || [ "$param" = "-p" ]; then
			export UPDATE_POOTLE_DB=1
		elif [ "$param" = "--rescanfile" ] || [ "$param" = "-s" ]; then
			export RESCAN_FILES=1
		elif [ "$param" = "--moveproject" ] || [ "$param" = "-m" ]; then
			export MOVE_PROJECT=1
		elif [ "$param" = "--backport" ] || [ "$param" = "-b" ]; then
			export BACKPORT=1
		elif [ "$param" = "--upload" ] || [ "$param" = "-u" ]; then
			export UPLOAD=1
		elif [ "$param" = "--uploadDerived" ] || [ "$param" = "-U" ]; then
			export UPLOAD_DERIVED=1
		elif [ "$param" = "--newproject" ] || [ "$param" = "-np" ]; then
			export NEW_PROJECT=1
		elif [ "$param" = "--deleteproject" ] || [ "$param" = "-dp" ]; then
			export DELETE_PROJECT=1
		elif [ "$param" = "--qualityCheck" ] || [ "$param" = "-q" ]; then
			export QA_CHECK=1
		elif [ "$param" = "--restoreBackup" ] || [ "$param" = "-rB" ]; then
			export RESTORE_BACKUP=1
		elif [ "$param" = "--createBackup" ] || [ "$param" = "-cB" ]; then
			export CREATE_BACKUP=1
		elif [ "$param" = "--listProjects" ] || [ "$param" = "-l" ]; then
			export LIST_PROJECTS=1
		elif [ "$param" = "--provisionProjects" ] || [ "$param" = "-pp" ]; then
			export PROVISION_PROJECTS=1
		elif [ "$param" = "--provisionProjectsOnlyCreate" ] || [ "$param" = "-ppc" ]; then
			export PROVISION_PROJECTS_ONLY_CREATE=1
		elif [ "$param" = "--provisionProjectsOnlyDelete" ] || [ "$param" = "-ppd" ]; then
			export PROVISION_PROJECTS_ONLY_DELETE=1
		elif [ "$param" = "--provisionProjectsDummy" ] || [ "$param" = "-ppD" ]; then
			export PROVISION_PROJECTS_DUMMY=1
		elif [ "$param" = "--spreadTranslations" ] || [ "$param" = "-S" ]; then
			export SPREAD_TRANSLATIONS=1
		elif [ "$param" = "--help" ] && [ "$param" = "-h" ] && [ "$param" = "/?" ]; then
			export HELP=1
		else
			echo "Unknown parameter. Showing help..."
			export HELP=1
		fi
	done
	if [ $HELP ]; then
		print_help
	fi
}

# -u and -U: allow to specify an URL for Language file download (ie github)
# add -c option to clean all branches related to tool operation
# add option to clean old logs/backups
# add --only-portal --only-plugins options to work on a subset of the projects
# add --language to work just for one language

function print_help() {
	echo -e "$WHITE.: $product :.$COLOROFF"
	echo

	echo "$product_name is a tool that syncrhonizes translations from Liferay source code repository from/to a Pootle 2.1.6 installation"
	echo "Tool is invoked with one action at a time. Each action might have additional arguments."
	echo
	echo -e "${YELLOW}Environment variables$COLOROFF"
	echo "	LR_TRANS_MGR_PROFILE	configuration profile to load (see Configuration section)."
	echo "	LR_TRANS_MGR_TAIL_LOG	if value is 1, tool invocation will do tail on log file. This allows to track the execution in real time"
	echo " 	LR_TRANS_MGR_COLOR_LOG	if value is 1, tool logs will be coloured"
	echo
	echo -e "${YELLOW}Configuration$COLOROFF"
	echo "	Tool reads conf/manager.\$LR_TRANS_MGR_PROFILE.conf.sh file. Variables are documented in conf/manager.conf file"
	echo
	echo -e "${YELLOW}Logs$COLOROFF"
	echo "	Tool output is written into log file. Filename is shown in the console  "
	echo

	echo -e "${YELLOW}Actions$COLOROFF"

	print_action "-r, --pootle2repo"\
		"Exports translations from Pootle to Liferay source code. First, saves pootle data into Language*.properties files, makes some processing to the files, then commits them into a branch named $EXPORT_BRANCH (created from a fresh copy of working branch) and pushes it to the configured remote repository.
		Then sends a pull request to the branch maintainer. Repositiry, Working branch and maintainer github nick name are configurable (see conf directory)"

	print_action "-p, --repo2pootle"\
		"Updates in Pootle the set of translatable available in the Language.properties files from a fresh copy of master (or specified branch). After that, updates all translations that have been \
committed to master (or specified branch) since last commit done by the tool as a result of -r action. This allows developers to commit translations directly on master (or specified branch) w/o using Pootle."

	print_action "-R, --repo2pootle2repo"\
		"Runs a complete roundrtip from with -p, then with -r"

	print_action "-s, --rescanfile"\
		"Instructs Pootle to rescan filesystem to update the filenames in the DB. This basically avoids doing the same using the UI (saving a lot of time).\
In addition, corrects any filename not matching Language_<locale>.properties naming convention"

	print_action "-S, --spreadTranslations <sourceProjectCode>"\
			"Spreads translations from an existing project to the other projects in the same git root. Useful when moving translations between projects, and those translations are only in pootle DB.\
			The detailed process is as follows: first, source git root is synced to get the latest keys and translations from source code. Then, pootle exports the source project translations into a \
			temp dir, which is used to copy all available translations in the destination projects. Result is that translations in pootle for sourceProject are copied into target projects, then committed."\
			"sourceProjectCode: project code which translations will be exported from pootle and spread to the other projectcs"\

	print_action "-m, --moveproject <currentCode> <newCode>"\
		"Changes the project code in Pootle. This operation is not supported by Pootle. Truly useful in case a plugin name changes"\
		"currentCode: project current code, such as 'knowledge-portlet'"\
		"newCode: project new code, such as 'knowledge-base-portlet'"

	print_action "-b, --backport [<sourceBranch> <targetBranch>]"\
		"Backports translations from source to destination branch. This action just works with branches, there is no communication with the Pootle server nor filesystem. It's recommended \
to run with -R prior to make any backport. Results are committed and pushed to a remote branch created from the tip of the destination branch, which name contains a timestamp. Source \
and target directories are defined in \$SRC_PORTAL_BASE and \$SRC_PORTAL_EE_BASE for portal, and \$SRC_PLUGINS_BASE and \$SRC_PLUGINS_EE_BASE for plugins respectively. Source and target branches \
are optional arguments but have to be provided together to take effect"\
		"sourceBranch: (optional) branch to be checkout in \$SRC_PORTAL_BASE and \$SRC_PLUGINS_BASE prior to start the backport"\
 		"targetBranch: (optional) branch to be checkout in \$SRC_PORTAL_EE_BASE and \$SRC_PLUGINS_EE_BASE prior to start the backport. This branch will act as base for the resulting commits"\

	print_action "-u, --upload <projectCode> <locale>"\
			"Uploads translations for a given project and language. Translations are read from Language_<locale>.properties file in the pwd. \
Automatic translations are not uploaded. If there is a Language.properties in the pwd, will be read as well so that \
translations which value equal to the english translation is skipped as well."\
			"projectCode: project code, such as 'knowledge-portlet'"\
			"locale: locale code denoting language where translations will be uploaded"

	print_action "-U, --uploadDerived <projectCode> <derivedLocale> <parentLocale>"\
			"Uploads translations for a given project and language which is derived from a parent language.\
Automatic translations are not uploaded. If a translation in derived language is found to be equal to its peer in parent locale, then it won't be uploaded. As a result,\
the translation in the parent locale will be used by Liferay when a page is requested in the derived locale, simplifying the administration.\
Both Language_<parentLocale>.properties and Language_<derivedLocale>.properties have to be in the pwd\
Future version are expected to read a Language.properties file as well to match the -u behavior"\
			"projectCode: project code, such as 'knowledge-portlet'"\
			"derivedLocale: locale code denoting language where translations will be uploaded"\
			"parentLocale: locale code denoting the parent language, which translations will be reused by the derived one "

	print_action "-np, --newproject <projectCode> \"<project name>\""\
			"Creates a new project in Pootle. In addition, creates all languages in the project, generating project files as expected by -r and -p options. This saves a lot of time"\
			"projectCode: new project code, such as 'knowledge-portlet'"\
			"projectName: new project name, such as 'Knowledge Portlet'. If contains spaces, please double quote it!"\

	print_action "-dp, --deleteproject <projectCode>"\
			"Deletes an existing project in Pootle. "\
			"projectCode: project code, such as 'knowledge-portlet'"

	print_action "-pp, --provisionProjects"\
			"Detects projects from source code (git roots) and syncs the sets of projects in Pootle according to detected projects"

	print_action "-ppc, --provisionProjectsOnlyCreate"\
			"Detects projects from source code (git roots) and just creates the set of projects in Pootle according to detected projects.\
Projects in pootle that ceased to exist in sources are kept."

	print_action "-ppd, --provisionProjectsOnlyDelete"\
			"Detects projects from source code (git roots) and just deletes the set of projects in Pootle according to detected projects.\
Projects in sources that don't exist in pootle won't be created."

	print_action "-ppD, --provisionProjectsDummy"\
			"Detects projects from source code (git roots) and just tells what would be created/deleted in pootle.\
No projects are created/deleted in pootle."

	print_action "-q, --qualityCheck"\
			"Run a set of checks over pootle exported files. Log files contain the results"

	print_action "-rB, --restoreBackup <backupID>" "Restores a Pootle data backup given its ID. The backup id is provided in the logs whenever the invoked action requires a backup"\
			"backupID: the backup ID which will be used to locate backup files to be restored"

	print_action "-cB, --createBackup" "Creates a backup. Log will show the backupId that can be used to restore"

	print_action "-l, --listProjects" "List all projects configured for the $LR_TRANS_MGR_PROFILE profile "

	print_action "-h, --help" "Prints this help and exits"

	UPDATE_REPOSITORY=
	UPDATE_POOTLE_DB=
}

function print_action() {
	echo -e "	${CYAN}$1$COLOROFF"
	shift 1
	echo "		$1"
	shift 1
	[[ ! -z $1 ]] && echo "		Arguments:"
	for arg in "$@";
	do
		echo "			$arg"
	done;
	echo
}

function set_colors() {
	if [[ "${LR_TRANS_MGR_COLOR_LOG}x" == "1x" ]]; then
		COLOROFF="\033[1;0m"; GREEN="\033[1;32m"; RED="\033[1;31m"; LILA="\033[1;35m"
		YELLOW="\033[1;33m"; BLUE="\033[1;34m"; WHITE="\033[1;37m"; CYAN="\033[1;36m";
		LIGHT_GRAY="\033[0;37m"
	fi
}

function load_config() {
	if [[ -n "$LR_TRANS_MGR_PROFILE" ]]; then
		pmp="manager.$LR_TRANS_MGR_PROFILE.conf.sh"
		msg="Loaded configuration profile '$pmp'"
	else
		echo "I don't know which configuration profile I have to load. Please define LR_TRANS_MGR_PROFILE to match some conf/manager.\$LR_TRANS_MGR_PROFILE.conf.sh file "
		exit 1
	fi;

	set_colors

	. "conf/${pmp}"

	set_log_dir

	logt 1 "$msg"
}
