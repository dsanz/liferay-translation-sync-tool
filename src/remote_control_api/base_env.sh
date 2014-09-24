export BASH_HOME=/opt/bash-4.3
export SYNC_TOOL_HOME=/opt/liferay-pootle-manager/src
export HOME_DIR="$(dirname $(readlink -f $BASH_SOURCE))"


function run_sync_tool() {
  $BASH_HOME/bash $SYNC_TOOL_HOME/pootle-manager.sh $@
}