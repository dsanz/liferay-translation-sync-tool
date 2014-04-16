#!/bin/bash

###
### Configuration file for the DEV environment
### please remember to export LR_TRANS_MGR_PROFILE="dev" for this file to be read by the script.
###

################################################################################
### Section 1: Pootle server installation
###

## 1.1 Directories
##
# manage.py will be invoked here. Can be a standalone or module installation
declare -xgr MANAGE_DIR="/usr/local/lib/python2.7/dist-packages/django/conf/project_template"
# python path for the pootle module. Leave it blank in standalone installations
declare -xgr POOTLE_PYTHONPATH="/opt/Pootle-2.1.6"
# name settings for pootle module. Leave it blank in standalone installations
declare -xgr POOTLE_SETTINGS="pootle.settings"
# location of translation files for Pootle DB update/sync
declare -xgr PODIR="/opt/Pootle-2.1.6/po"
# fs credentials. Used to restore Pootle exported files ownership inside $PODIR
declare -xgr FS_UID="dsanz"
declare -xgr FS_GID="dsanz"

## 1.2 Pootle server http access
##           (allows us to communicate with a living pootle server)
# server URL
declare -xgr PO_HOST="localhost"
declare -xgr PO_PORT="8080"
declare -xgr PO_SRV="http://$PO_HOST:$PO_PORT"
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
declare -xgr MYSQL_COMMAND="mysql -u$DB_USER -p$DB_PASS"
declare -xgr MYSQL_DUMP_COMMAND="mysqldump -u$DB_USER -p$DB_PASS"

################################################################################
### Section 2: Dirs and files required to work
###

## 2.1 Working dirs
##
# all temp/work dirs are under BASE_DIR
declare -xgr BASE_DIR="/var/tmp"
declare -xgr TMP_DIR="$BASE_DIR/po-lf"
declare -xgr TMP_PROP_IN_DIR="$TMP_DIR/prop_in"
declare -xgr TMP_PROP_OUT_DIR="$TMP_DIR/prop_out"
declare -xgr TMP_DB_BACKUP_DIR="$BASE_DIR/db-backups"
declare -xgr LOG_DIR="$BASE_DIR/log"

## 2.2 Liferay source dirs. Git
##   (under git control, where forked & cloned repos are)
# Those are required both for backport and for writing pootle export results.
# EE repos are useful only for backport. CE repos are used for pootle sync
declare -xgr SRC_BASE="/home/dsanz/projects/"
declare -xgr SRC_PORTAL_BASE="${SRC_BASE}liferay-portal/"
declare -xgr SRC_PORTAL_EE_BASE="${SRC_BASE}liferay-portal-ee/"
declare -xgr SRC_PORTAL_LANG_PATH="portal-impl/src/content/"
declare -xgr SRC_PLUGINS_BASE="${SRC_BASE}liferay-plugins/"
declare -xgr SRC_PLUGINS_EE_BASE="${SRC_BASE}liferay-plugins-ee/"
declare -xgr SRC_PLUGINS_LANG_PATH="/docroot/WEB-INF/src/content/"

# Git branches management
declare -xgr WORKING_BRANCH="to-pootle-working"
declare -xgr LAST_BRANCH="child-of-latest-export-to-liferay"
declare -xgr EXPORT_BRANCH="pootle-export"

## 2.3 File naming
##
# How does language file look like (e.g. Language.properties)
declare -xgr FILE="Language"
declare -xgr PROP_EXT="properties"
declare -xgr LANG_SEP="_"

################################################################################
## Section 3: Translation projects
##

## 3.1 List of plugins
##
# Portlets
declare -xgr PORTLET_LIST="akismet calendar chat contacts ddl-form\
 events-display google-maps knowledge-base mail marketplace microblogs\
 opensocial plugins-security-manager polls private-messaging social-coding\
 social-networking so tasks twitter vimeo weather web-form wiki-navigation wsrp\
 youtube"
declare -xgr PORTLET_SUFFIX="-portlet"
declare -xgr PORTLET_SRC_PATH_PREFIX="${SRC_PLUGINS_BASE}portlets/"
# Themes
declare -xgr THEME_LIST="noir"
declare -xgr THEME_SUFFIX="-theme"
declare -xgr THEME_SRC_PATH_PREFIX="${SRC_PLUGINS_BASE}themes/"
# Hooks
declare -xgr HOOK_LIST="so-activities so shibboleth"
declare -xgr HOOK_SUFFIX="-hook"
declare -xgr HOOK_SRC_PATH_PREFIX="${SRC_PLUGINS_BASE}hooks/"

## 3.2 Master lists
##
# contains all project code names, as seen by pootle and source dirs
declare -xga PROJECT_NAMES
declare -xga PROJECT_SRC
declare -xga PROJECT_ANT
# master path lists
declare -xga PATH_PROJECTS
declare -xga PATH_BASE_DIR

## 3.3 project lists initialization
##
# first project is the Liferay portal itself
PORTAL_PROJECT_ID=portal
add_project "$PORTAL_PROJECT_ID" "$SRC_PORTAL_BASE$SRC_PORTAL_LANG_PATH"\
 "$SRC_PORTAL_BASE/portal-impl"
# now, some plugins
#add_projects "$PORTLET_LIST" $PORTLET_SUFFIX $PORTLET_SRC_PATH_PREFIX
#add_projects "$HOOK_LIST" $HOOK_SUFFIX $HOOK_SRC_PATH_PREFIX
# no translatable themes so far...
#add_projects "$THEME_LIST" $THEME_SUFFIX $THEME_SRC_PATH_PREFIX

## 3.4 path lists initialization
##
# now that PROJECTS is filled, create the paths
compute_working_paths

# make master lists readonly from now on
declare -r PROJECT_NAMES
declare -r PROJECT_SRC
declare -r PROJECT_ANT
declare -r PATH_PROJECTS
declare -r PATH_BASE_DIR

################################################################################
### Section 4: Environment
###

## ant
##
ANT_BIN="ant"
export ANT_OPTS="-Xmx1024m -XX:MaxPermSize=512m"


