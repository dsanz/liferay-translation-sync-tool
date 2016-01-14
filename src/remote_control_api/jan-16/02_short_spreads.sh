export HOME_DIR="$(dirname $(readlink -f $BASH_SOURCE))"

. $HOME_DIR/../base_env.sh

# collab & DM (Sergio)
# merge all social office announcements into announcements-web
run_sync_tool "-S" "social-office-announcements-web" "announcements-web"
run_sync_tool "-S" "so-announcements-portlet" "announcements-web"
# merge wiki-engine-mediawiki and wiki-engine-text into portal-impl
run_sync_tool "-S" "wiki-engine-mediawiki" "portal-impl"
run_sync_tool "-S" "wiki-engine-text" "portal-impl"

# WEM (Julio)
# spread from asset-publisher-web to a new asset-entry-query-processor-custom-user-attributes
run_sync_tool "-S" "asset-publisher-web" "asset-entry-query-processor-custom-user-attributes"
run_sync_tool "-S" "layouts-admin-web" "mobile-devices-rules-web"

# Staging (Mate)
run_sync_tool "-S" "export-import-web" "staging-lang"
run_sync_tool "-S" "staging-bar-web" "staging-lang"
run_sync_tool "-S" "staging-configuration-web" "staging-lang"

