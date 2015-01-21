export HOME_DIR="$(dirname $(readlink -f $BASH_SOURCE))"

. $HOME_DIR/base_env.sh

cat $SYNC_TOOL_HOME/conf/manager.pro.conf.sh