export HOME_DIR="$(dirname $(readlink -f $BASH_SOURCE))"

. $HOME_DIR/../base_env.sh

run_sync_tool "-rB" "2016-03-14_16-26-47"