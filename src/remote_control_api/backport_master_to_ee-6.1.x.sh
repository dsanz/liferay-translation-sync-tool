export HOME_DIR="$(dirname $(readlink -f $BASH_SOURCE))"

. $HOME_DIR/base_env.sh

run_sync_tool "-b" "master" "ee-6.1.x"