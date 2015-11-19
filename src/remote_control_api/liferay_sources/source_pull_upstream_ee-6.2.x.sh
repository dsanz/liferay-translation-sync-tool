export HOME_DIR="$(dirname $(readlink -f $BASH_SOURCE))"

. $HOME_DIR/../base_env.sh

pull_ee_branch "ee-6.2.x"
