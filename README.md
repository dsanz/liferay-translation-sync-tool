Liferay Translation Sync Tool
=============================

Liferay Translation Sync Tool is a tool that syncrhonizes translations from Liferay source code repository from/to a Pootle 2.1.6 installation

Tool installation is done by an installer which creates the liferay source repositories, and downloads and installs some tools.
The installer is not part of this distribution so far.

Tool is invoked with one action at a time. Each action might have additional arguments.

### Environment variables
 -` LR_TRANS_MGR_PROFILE`    configuration profile to load (see Configuration section).
 - `LR_TRANS_MGR_TAIL_LOG`   if value is 1, tool invocation will do tail on log file. This allows to track the execution in real time
 - `LR_TRANS_MGR_COLOR_LOG`  if value is 1, tool logs will be coloured

### Configuration
Tool reads conf/manager.$LR_TRANS_MGR_PROFILE.conf.sh file. Variables are documented in conf/manager.conf file

### Logs
Tool output is written into log file. Filename is shown in the console

### Actions
##### Synchronizing Liferay source code and pootle
`-r, --pootle2repo`

Exports translations from Pootle to Liferay source code. First, saves pootle data into Language*.properties files, makes some processing to the files, then commits them into a branch named $EXPORT_BRANCH (created from a fresh copy of working branch) and pushes it to the configured remote repository. 
Then sends a pull request to the branch maintainer. Repositiry, Working branch and maintainer github nick name are configurable (see conf directory)

`-p, --repo2pootle`

Updates in Pootle the set of translatable available in the Language.properties files from a fresh copy of master (or specified branch). After that, updates all translations that have been committed to master (or specified branch) since last commit done by the tool as a result of -r action. This allows developers to commit translations directly on master (or specified branch) w/o using Pootle.

`-R, --repo2pootle2repo`

Runs a complete roundrtip from with -p, then with -r

`-s, --rescanfile`

Instructs Pootle to rescan filesystem to update the filenames in the DB. This basically avoids doing the same using the UI (saving a lot of time).In addition, corrects any filename not matching Language_<locale>.properties naming convention

##### Project provisioning
`-m, --moveproject <currentCode> <newCode>`

Changes the project code in Pootle. This operation is not supported by Pootle. Truly useful in case a plugin name changes

Arguments:
 - `currentCode`: project current code, such as 'knowledge-portlet'
 - `newCode`: project new code, such as 'knowledge-base-portlet'

`-np, --newproject <projectCode> "<project name>"`

Creates a new project in Pootle. In addition, creates all languages in the project, generating project files as expected by -r and -p options. This saves a lot of time

Arguments:
 - `projectCode`: new project code, such as 'knowledge-portlet'
 - `projectName`: new project name, such as 'Knowledge Portlet'. If contains spaces, please double quote it!

`-dp, --deleteproject <projectCode>`

Deletes an existing project in Pootle.

Arguments:
 - `projectCode`: project code, such as 'knowledge-portlet'

`-pp, --provisionProjects`

Detects projects from source code (git roots) and syncs the sets of projects in Pootle according to detected projects

`-ppc, --provisionProjectsOnlyCreate`

Detects projects from source code (git roots) and just creates the set of projects in Pootle according to detected projects.Projects in pootle that ceased to exist in sources are kept.

`-ppd, --provisionProjectsOnlyDelete`

Detects projects from source code (git roots) and just deletes the set of projects in Pootle according to detected projects.Projects in sources that don't exist in pootle won't be created.

`-ppD, --provisionProjectsDummy`

Detects projects from source code (git roots) and just tells what would be created/deleted in pootle.No projects are created/deleted in pootle.

`-fpd, --fixPODir` 

Re-cretaes the project dir structure on disk (under $PODIR). Useful if some dir got deleted. Allows pootle to write the exported files, which in turn allows user to download them and the export sync to work properly

##### Tranlsation management

`S, --spreadTranslations <sourceProjectCode>`

Spreads translations from an existing project to the other projects in the same git root. Useful when moving translations between projects, and those translations are only in pootle DB.                       The detailed process is as follows: first, source git root is synced to get the latest keys and translations from source code. Then, pootle exports the source project translations into a                   temp dir, which is used to copy all available translations in the destination projects. Result is that translations in pootle for sourceProject are copied into target projects, then committed.

Arguments:
 - `sourceProjectCode`: project code which translations will be exported from pootle and spread to the other projectcs

`-b, --backport [<sourceBranch> <targetBranch>]`

Backports translations from source to destination branch. This action just works with branches, there is no communication with the Pootle server nor filesystem. It's recommended to run with -R prior to make any backport. Results are committed and pushed to a remote branch created from the tip of the destination branch, which name contains a timestamp. Source and target directories are defined in $SRC_PORTAL_BASE and $SRC_PORTAL_EE_BASE for portal, and $SRC_PLUGINS_BASE and $SRC_PLUGINS_EE_BASE for plugins respectively. Source and target branches are optional arguments but have to be provided together to take effect

Arguments:
 - `sourceBranch`: (optional) branch to be checkout in $SRC_PORTAL_BASE and $SRC_PLUGINS_BASE prior to start the backport
 - `targetBranch`: (optional) branch to be checkout in $SRC_PORTAL_EE_BASE and $SRC_PLUGINS_EE_BASE prior to start the backport. This branch will act as base for the resulting commits

`-u, --upload <projectCode> <locale>`

Uploads translations for a given project and language. Translations are read from Language_<locale>.properties file in the pwd. Automatic translations are not uploaded. If there is a Language.properties in the pwd, will be read as well so that translations which value equal to the english translation is skipped as well.

Arguments:
 - `projectCode`: project code, such as 'knowledge-portlet'
 - `locale`: locale code denoting language where translations will be uploaded

`-U, --uploadDerived <projectCode> <derivedLocale> <parentLocale>`

Uploads translations for a given project and language which is derived from a parent language.Automatic translations are not uploaded. If a translation in derived language is found to be equal to its peer in parent locale, then it won't be uploaded. As a result,the translation in the parent locale will be used by Liferay when a page is requested in the derived locale, simplifying the administration.Both Language_<parentLocale>.properties and Language_<derivedLocale>.properties have to be in the pwdFuture version are expected to read a Language.properties file as well to match the -u behavior

Arguments:
 - `projectCode`: project code, such as 'knowledge-portlet'
 - `derivedLocale`: locale code denoting language where translations will be uploaded
 - `parentLocale`: locale code denoting the parent language, which translations will be reused by the derived one


`-q, --qualityCheck`
Runs a set of checks over pootle exported files. Log files contain the results


##### Backups
`-cB, --createBackup`

Creates a backup. Log will show the backupId that can be used to restore

`-rB, --restoreBackup <backupID>`

Restores a Pootle data backup given its ID. The backup id is provided in the logs whenever the invoked action requires a backup

Arguments:
 - `backupID`: the backup ID which will be used to locate backup files to be restored


##### Other
`-l, --listProjects`

List all projects configured for the dev profile

`-h, --help, (or no arguments)`

Prints this help and exits


