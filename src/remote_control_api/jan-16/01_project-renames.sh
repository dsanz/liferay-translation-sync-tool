export HOME_DIR="$(dirname $(readlink -f $BASH_SOURCE))"

. $HOME_DIR/../base_env.sh

# collab & DM (Sergio)
run_sync_tool "-m" "flags-page-flags-web" "flags-web"
#run_sync_tool "-m" "notifications-portlet" "notifications-web"
#run_sync_tool "-m" "wiki-navigation-portlet" "wiki-navigation-web"
# UI (Chema)
#run_sync_tool "-m" "frontend-editors-web" "frontend-editor-lang"