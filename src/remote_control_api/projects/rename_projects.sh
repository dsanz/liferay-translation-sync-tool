export HOME_DIR="$(dirname $(readlink -f $BASH_SOURCE))"

. $HOME_DIR/../base_env.sh

run_sync_tool "-m" "portal" "portal-impl"
run_sync_tool "-m" "ddl-form-portlet" "dynamic-data-lists-form-web"
run_sync_tool "-m" "social-networking-portlet" "social-networking-web"
run_sync_tool "-m" "marketplace-portlet" "marketplace-store-web"