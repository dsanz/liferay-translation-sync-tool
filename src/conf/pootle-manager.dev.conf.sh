#!/bin/bash

###
### Configuration file for the DEV environment
### please remember to export LR_TRANS_MGR_PROFILE="dev" for this file to be read by the script.
###

## Configuration of directories
## base dirs
# pootle installation
declare -xgr POOTLEDIR="/opt/Pootle-2.1.6"
# translation files for Pootle DB update/sync
declare -xgr PODIR="$POOTLEDIR/po"
# base working dir for the scripts
declare -xgr BASE_DIR="/var/tmp"
# temporal working dirs
declare -xgr TMP_DIR="$BASE_DIR/po-lf"
declare -xgr TMP_PROP_IN_DIR="$TMP_DIR/prop_in"
declare -xgr TMP_PROP_OUT_DIR="$TMP_DIR/prop_out"
declare -xgr TMP_DB_BACKUP_DIR="$BASE_DIR/db-backups"
declare -xgr LOG_DIR="$BASE_DIR/log"
# source dirs, under git control, where forked & cloned repos are
declare -xgr SRC_BASE="/home/dsanz/projects/"
declare -xgr SRC_PORTAL_BASE="${SRC_BASE}/trunk/src-portal/portal/"
declare -xgr SRC_PORTAL_EE_BASE="${SRC_BASE}/portal-ee/liferay-portal-ee"
declare -xgr SRC_PORTAL_LANG_PATH="portal-impl/src/content/"
declare -xgr SRC_PLUGINS_BASE="${SRC_BASE}/trunk/src-plugins/plugins/"
declare -xgr SRC_PLUGINS_EE_BASE="${SRC_BASE}/portal-ee/liferay-plugins-ee"
declare -xgr SRC_PLUGINS_LANG_PATH="/docroot/WEB-INF/src/content/"

## Configuration of credentials
# a valid pootle user with administration privileges
declare -xgr PO_USER="manager"
declare -xgr PO_PASS="test"
# db credentials are not required for now

## Configuration of servers
# allows us to communicate with a living pootle server, installed under $POOTLE_DIR
declare -xgr PO_HOST="localhost"
declare -xgr PO_PORT="8080"
declare -xgr PO_SRV="http://$PO_HOST:$PO_PORT"
declare -xgr PO_PROJECTS_URL="$PO_SRV/projects"
declare -xgr PO_COOKIES="$BASE_DIR/${PO_HOST}_${PO_PORT}_cookies.txt"

## Git branches management
declare -xgr WORKING_BRANCH="to-pootle-working"
declare -xgr LAST_BRANCH="child-of-latest-export-to-liferay"
declare -xgr EXPORT_BRANCH="pootle-export"

## List of projects we know about
declare -xgr PORTLET_LIST="akismet calendar chat contacts ddl-form events-display google-maps knowledge-base mail\
 marketplace mb-subscription-manager microblogs modules-admin notifications opensocial plugins-security-manager\
 private-messaging social-coding social-networking so so-announcements tasks twitter vimeo web-form wiki-navigation\
 wsrp youtube"
declare -xgr PORTLET_SUFFIX="-portlet"
declare -xgr PORTLET_SRC_PATH_PREFIX="${SRC_PLUGINS_BASE}portlets/"

declare -xgr THEME_LIST="noir"
declare -xgr THEME_SUFFIX="-theme"
declare -xgr THEME_SRC_PATH_PREFIX="${SRC_PLUGINS_BASE}themes/"

declare -xgr HOOK_LIST="so-activities so shibboleth"
declare -xgr HOOK_SUFFIX="-hook"
declare -xgr HOOK_SRC_PATH_PREFIX="${SRC_PLUGINS_BASE}hooks/"

## master project list
# contains all project code names, as seen by pootle and source dirs
declare -xga PROJECT_NAMES
declare -xga PROJECT_SRC
declare -xga PROJECT_ANT
# master path list
declare -xga PATH_PROJECTS
declare -xga PATH_BASE_DIR

# first project is the Liferay portal itself
declare -xga PORTAL_PROJECT_ID=portal
add_project "$PORTAL_PROJECT_ID" "$SRC_PORTAL_BASE$SRC_PORTAL_LANG_PATH" "$SRC_PORTAL_BASE/portal-impl"

# now, some plugins
add_projects "$PORTLET_LIST" $PORTLET_SUFFIX $PORTLET_SRC_PATH_PREFIX
add_projects "$HOOK_LIST" $HOOK_SUFFIX $HOOK_SRC_PATH_PREFIX
#add_projects "$THEME_LIST" $THEME_SUFFIX $THEME_SRC_PATH_PREFIX    # no translatable themes so far...

# now that PROJECTS is filled, create the paths
compute_working_paths

# make master lists readonly from now on
declare -r PROJECT_NAMES
declare -r PROJECT_SRC
declare -r PROJECT_ANT
declare -r PATH_PROJECTS
declare -r PATH_BASE_DIR

# How does language file look like (e.g. Language.properties)
declare -xgr FILE="Language"
declare -xgr PROP_EXT="properties"
declare -xgr LANG_SEP="_"

# How DB dump/restore commands look like (depends on pootle installation)
declare -xgr DB_NAME="pootle"
declare -xgr MYSQL_COMMAND="mysql"
declare -xgr DB_DUMP_COMMAND="mysqldump"

#ant
ANT_BIN="ant"
export ANT_OPTS="-Xmx1024m -XX:MaxPermSize=512m"

