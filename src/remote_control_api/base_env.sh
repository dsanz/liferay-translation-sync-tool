export BASH_HOME=/opt/bash-4.3
export SYNC_TOOL_HOME=/opt/liferay-pootle-manager/src

function run_sync_tool() {
  $BASH_HOME/bash $SYNC_TOOL_HOME/pootle-manager.sh $@
}