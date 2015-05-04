#!/bin/bash

###
### Configuration file for the DEV environment
### please remember to export LR_TRANS_MGR_PROFILE="dev" for this file to be read by the script.
###

################################################################################
### Section 0: Environment
###
### Note: setEnv script should have defined some *_HOME variables.

## working dirs
# all temp/work dirs are under BASE_DIR
declare -xgr BASE_DIR="/opt"

## ant
##
export ANT_BIN="$ANT_HOME/bin/ant"
export ANT_OPTS="-Xmx1024m -XX:MaxPermSize=512m"

## java
export NATIVE2ASCII_BIN="$JAVA_HOME/bin/native2ascii"

## bc
export BC_BIN="$BC_HOME/bc/bc"

## hub (git + hub = github)
export HUB_BIN="$HUB_HOME/hub"

## ansi2html
export ANSI2HTML_BIN="$ANSI2HTML_HOME/ansi2html.sh"

################################################################################
### Section 1: Pootle server installation
###

## 1.1 Directories
##
# manage.py will be invoked here. Can be a standalone or module installation
declare -xgr MANAGE_DIR="/usr/lib/python2.6/site-packages/django/conf/project_template"
# python path for the pootle module. Leave it blank in standalone installations
declare -xgr POOTLE_PYTHONPATH=""
# name settings for pootle module. Leave it blank in standalone installations
declare -xgr POOTLE_SETTINGS="pootle.settings"
# location of translation files for Pootle DB update/sync
declare -xgr PODIR="/var/lib/pootle/po"
# fs credentials. Used to restore Pootle exported files ownership inside $PODIR
declare -xgr FS_UID="apache"
declare -xgr FS_GID="apache"

## 1.2 Pootle server http access
##           (allows us to communicate with a living pootle server)
# server URL
declare -xgr PO_HOST="cloud-10-50-0-102.liferay.com"
declare -xgr PO_PORT="80"
declare -xgr PO_SRV="https://$PO_HOST/pootle"
declare -xgr PO_COOKIES="$TMP_DIR/${PO_HOST}_${PO_PORT}_cookies.txt"
# a valid pootle user with administration privileges
declare -xgr PO_USER="manager"
declare -xgr PO_PASS="test"
# common options for all curl invocations along the scripts
declare -xgr CURL_OPTS="-s -L -k -o /dev/null -b $PO_COOKIES -c $PO_COOKIES"

## 1.3 Pootle database
##
# db credentials
declare -xgr DB_USER="root"
declare -xgr DB_PASS="test"
# How DB dump/restore commands look like (depends on pootle installation)
declare -xgr DB_NAME="pootle"
declare -xgr MYSQL_COMMAND="mysql"
declare -xgr MYSQL_DUMP_COMMAND="mysqldump"

################################################################################
### Section 2: Dirs and files required to work
###

## 2.1 Working dirs
##
# all temp/work dirs are under BASE_DIR
declare -xgr TMP_DIR="$BASE_DIR/po-lf"
declare -xgr TMP_PROP_IN_DIR="$TMP_DIR/prop_in"
declare -xgr TMP_PROP_OUT_DIR="$TMP_DIR/prop_out"
declare -xgr TMP_DB_BACKUP_DIR="$BASE_DIR/db-backups"
declare -xgr LOG_DIR="$BASE_DIR/log"

## 2.2 Liferay source dirs. Git
##   (under git control, where forked & cloned repos are)
# Those are required both for backport and for writing pootle export results.
# EE repos are useful only for backport. CE repos are used for pootle sync

# general variables
declare -xgr SRC_BASE="$BASE_DIR/"
declare -xgr SRC_CONTENT="src/content/"

# liferay portal
declare -xgr SRC_PORTAL_BASE="${SRC_BASE}liferay-portal/"
declare -xgr SRC_PORTAL_EE_BASE="${SRC_BASE}liferay-portal-ee/"
declare -xgr SRC_PORTAL_LANG_PATH="portal-impl/$SRC_CONTENT"

# liferay plugns
declare -xgr SRC_PLUGINS_BASE="${SRC_BASE}liferay-plugins/"
declare -xgr SRC_PLUGINS_EE_BASE="${SRC_BASE}liferay-plugins-ee/"
declare -xgr SRC_PLUGINS_LANG_PATH="docroot/WEB-INF/$SRC_CONTENT"

# liferay apps for content targeting
declare -xgr SRC_APPS_CT_BASE="${SRC_BASE}liferay-apps-content-targeting/"
declare -xgr SRC_APPS_CT_LANG_PATH="$SRC_CONTENT"

## 2.3 Git & github
##

# Git branches management
declare -xgr EXPORT_BRANCH="pootle-export"

# Git commit msg (all commits to portal master require an LPS number)
declare -xgr LPS_CODE="LPS-00000"

# GitHub pull request default reviewer
declare -xgr DEFAULT_PR_REVIEWER="dsanz"

## 2.4 File naming
##
# How does language file look like (e.g. Language.properties)
declare -xgr FILE="Language"
declare -xgr PROP_EXT="properties"
declare -xgr LANG_SEP="_"

################################################################################
## Section 3: Translation projects
##

## 3.0 Master lists
##
# contains all project code names, as seen by pootle and source dirs
declare -xgA PROJECT_NAMES
# contains an entry for each project, storing the project base source dir where Language.properties files are
declare -xgA PROJECT_SRC_LANG_BASE
# contains an entry for each project, storing the ant dir where build-lang target is to be invoked
declare -xgA PROJECT_ANT_BUILD_LANG_DIR
# contains an entry for each different base source dir, storing the list of
# projects associated with that dir
declare -xgA PROJECTS_BY_GIT_ROOT
# contains an entry for each git repo we are working with. It stores the root dir for each repo.
declare -xgA GIT_ROOTS
# holds a list of github account names for the reviewer of each git root
declare -xgA PR_REVIEWER

## 3.1 List of plugins from the Liferay plugins repo
##
# plugin type constants
declare -xgr PORTLET="portlet"
declare -xgr THEME="theme"
declare -xgr HOOK="hook"
declare -xgr WEB="web"

# Portlets
declare -xgr PORTLET_LIST="akismet\
 calendar chat contacts\
 ddl-form\
 events-display\
 google-maps\
 knowledge-base\
 mail marketplace microblogs\
 notifications\
 opensocial\
 private-messaging push-notifications\
 social-coding so\
 tasks twitter\
 vimeo\
 web-form wiki-navigation wsrp\
 youtube"
# Themes
declare -xgr THEME_LIST="noir"
# Hooks
declare -xgr HOOK_LIST="so-activities so"

## 3.2 List of apps for content targeting
##
declare -xgr APPS_CT_MODULE_LIST="content-targeting-api\
 report-campaign-content report-campaign-tracking-action report-user-segment-content\
 rule-age rule-browser rule-device rule-facebook rule-gender rule-ip-geocode rule-organization-member\
 rule-os rule-role rule-site-member rule-score-points rule-time rule-user-group-member rule-user-logged rule-visited\
 tracking-action-content tracking-action-form tracking-action-link tracking-action-page tracking-action-youtube"
declare -xgr APPS_CT_WEB_LIST="content-targeting"
declare -xgr APPS_CT_HOOK_LIST="analytics\
 simulator"

## 3.3 project lists initialization
##
# first project is the Liferay portal itself
PORTAL_PROJECT_ID=portal
#add_git_root "$SRC_PORTAL_BASE"
add_git_root "$SRC_PLUGINS_BASE"
#add_git_root "$SRC_APPS_CT_BASE"

#add_project "$PORTAL_PROJECT_ID" "$SRC_PORTAL_BASE" "$SRC_PORTAL_LANG_PATH" "/portal-impl"
# now, some plugins
add_projects_Liferay_plugins "$PORTLET_LIST" "$PORTLET" "$SRC_PLUGINS_BASE" "$SRC_PLUGINS_LANG_PATH"
#add_projects_Liferay_plugins "so" "$PORTLET" "$SRC_PLUGINS_BASE" "$SRC_PLUGINS_LANG_PATH"
add_projects_Liferay_plugins "$HOOK_LIST" "$HOOK" "$SRC_PLUGINS_BASE" "$SRC_PLUGINS_LANG_PATH"
# no translatable themes so far...
#add_projects_Liferay_plugins "$THEME_LIST" "$THEME" "$SRC_PLUGINS_BASE" "$SRC_PLUGINS_LANG_PATH"

# content targeting apps
#add_projects "$APPS_CT_MODULE_LIST" "$SRC_APPS_CT_BASE" "$SRC_APPS_CT_LANG_PATH"
#add_projects_Liferay_plugins "$APPS_CT_HOOK_LIST" "$HOOK"  "$SRC_APPS_CT_BASE"  "$SRC_PLUGINS_LANG_PATH" ""
#add_projects_Liferay_plugins "$APPS_CT_WEB_LIST" "$WEB"  "$SRC_APPS_CT_BASE"  "$SRC_PLUGINS_LANG_PATH" ""

# make master lists readonly from now on
declare -r PROJECT_NAMES
declare -r PROJECT_SRC_LANG_BASE
declare -r PROJECT_ANT_BUILD_LANG_DIR
declare -r PROJECTS_BY_GIT_ROOT
declare -r GIT_ROOTS
declare -r PR_REVIEWER