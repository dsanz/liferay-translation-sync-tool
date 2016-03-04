#!/bin/bash

#
# Configuration file documentation
#
# to create a new conf file:
#  1. copy this one into manager.<profilename>.conf.sh
#  2. define correct values for each variable
#  3. set LR_TRANS_MGR_PROFILE="<profilename>" env var prior to run the manager

################################################################################
### Section 0: Environment
###

### Note: setEnv script should have defined all required variables.
## here you can override them (proper solution would be to generate a correct setEnv.sh)

################################################################################
### Section 1: Pootle server installation
###

## 1.1 Directories
##
# manage.py will be invoked here. Can be a standalone or module installation
declare -xgr MANAGE_DIR="/var/www/Pootle"
# python path for the pootle module. Leave it blank in standalone installations
declare -xgr POOTLE_PYTHONPATH=""
# name settings for pootle module. Leave it blank in standalone installations
declare -xgr POOTLE_SETTINGS=""
# location of translation files for Pootle DB update/sync
declare -xgr PODIR="$MANAGE_DIR/po"
# fs credentials. Used to restore Pootle exported files ownership inside $PODIR
declare -xgr FS_UID="apache"
declare -xgr FS_GID="apache"

## 1.2 Pootle server http access
##           (allows us to communicate with a living pootle server)
# server URL
declare -xgr PO_HOST="localhost"
declare -xgr PO_PORT="8080"
declare -xgr PO_SRV="http://$PO_HOST:$PO_PORT"
declare -xgr PO_COOKIES="$BASE_DIR/${PO_HOST}_${PO_PORT}_cookies.txt"
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

# liferay portal
declare -xgr SRC_PORTAL_BASE="${SRC_BASE}liferay-portal/"
declare -xgr SRC_PORTAL_EE_BASE="${SRC_BASE}liferay-portal-ee/"

# liferay plugns
declare -xgr SRC_PLUGINS_BASE="${SRC_BASE}liferay-plugins/"
declare -xgr SRC_PLUGINS_EE_BASE="${SRC_BASE}liferay-plugins-ee/"

# liferay apps for content targeting
declare -xgr SRC_APPS_CT_BASE="${SRC_BASE}liferay-apps-content-targeting/"

## 2.3 Git & github
##

# Git branches management
declare -xgr EXPORT_BRANCH="pootle-export"
declare -xgr DEFAULT_SYNC_BRANCH="master"

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
# declare variables prefixed with AP_ which will be the "Auto Provisioned"
# counterparts for the old master lists
# GIT_ROOTS and PR_REVIEWER are the only variables which will be given to the tool, via add_git_root calls

# contains all project code names, as seen by pootle and source dirs
declare -xgA AP_PROJECT_NAMES
# contains an entry for each project, storing the project base source dir where Language.properties files are
declare -xgA AP_PROJECT_SRC_LANG_BASE
# contains an entry for each project, storing the ant dir where build-lang target is to be invoked
declare -xgA AP_PROJECT_BUILD_LANG_DIR
# contains an entry for each different base source dir, storing the list of
# projects associated with that dir
declare -xgA AP_PROJECTS_BY_GIT_ROOT
# contains an entry for each project, storing the project's git root
declare -xgA AP_PROJECT_GIT_ROOT
# contains an entry for each git repo we are working with. It stores the root dir for each repo.
declare -xgA GIT_ROOTS
# holds a list of github account names for the reviewer of each git root
declare -xgA PR_REVIEWER
# contains the pootle project name corresponding to each git root
declare -xgA GIT_ROOT_POOTLE_PROJECT_NAME

## 3.1 Auto-provisioning lists
##
# projects code that won't be deleted from pootle even if there is no source
# code associated
declare -xga POOTLE_PROJECT_DELETION_WHITELIST_REGEXS=(sync terminology lcs-portlet)

# if Language.properties file path matches any of these regexs, the project won't be
# considered for auto-provisioing, therefore it will not be created
declare -xga POOTLE_PROJECT_PATH_BLACKLIST_REGEXS=(build/ classes/ /localization)

## 3.3 project lists initialization
##
# first project is the Liferay portal itself
PORTAL_PROJECT_ID=portal-impl
add_git_root "$SRC_PORTAL_BASE"
add_git_root "$SRC_PLUGINS_BASE"
add_git_root "$SRC_APPS_CT_BASE" juliocamarero develop

