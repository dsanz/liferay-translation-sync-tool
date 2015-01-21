export BASH_HOME=/opt/bash-4.3
export SYNC_TOOL_HOME=/opt/liferay-pootle-manager/src
export HOME_DIR="$(dirname $(readlink -f $BASH_SOURCE))"

# source code repos
declare -xgr BASE_DIR="/opt"

declare -xgr SRC_BASE="$BASE_DIR/"

# liferay portal
declare -xgr SRC_PORTAL_BASE="${SRC_BASE}liferay-portal/"
declare -xgr SRC_PORTAL_EE_BASE="${SRC_BASE}liferay-portal-ee/"

# liferay plugns
declare -xgr SRC_PLUGINS_BASE="${SRC_BASE}liferay-plugins/"
declare -xgr SRC_PLUGINS_EE_BASE="${SRC_BASE}liferay-plugins-ee/"

# liferay apps for content targeting
declare -xgr SRC_APPS_CT_BASE="${SRC_BASE}liferay-apps-content-targeting/"

function run_sync_tool() {
  echo "Running sync tool: $BASH_HOME/bash $SYNC_TOOL_HOME/pootle-manager.sh $@"
  cd $SYNC_TOOL_HOME
  $BASH_HOME/bash pootle-manager.sh $@ 2>&1
}

function git_pull_upstream() {
  echo "cd $1"
  cd $1
  echo "git checkout $2"
  git checkout $2
  echo "git pull upstream $2"
  git pull upstream $2
}

function pull_master() {
	echo "Pulling portal"
	git_pull_upstream "$SRC_PORTAL_BASE" "master"
	echo "Pulling plugins"
	git_pull_upstream "$SRC_PLUGINS_BASE" "master"
	echo "Pulling Audience Targeting"
	git_pull_upstream "SRC_APPS_CT_BASE" "master"
}

function pull_ee_branch() {
	echo "Pulling portal-ee"
	git_pull_upstream "$SRC_PORTAL_EE_BASE" "$1"
	echo "Pulling plugins-ee"
	git_pull_upstream "$SRC_PLUGINS_EE_BASE" "$1"
}