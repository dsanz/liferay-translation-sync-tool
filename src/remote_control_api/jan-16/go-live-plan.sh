# See https://docs.google.com/spreadsheets/d/1XlgPSBDawHORtZoZEksB2Vf0iG-jWvAj_LxZqi8mx4M/edit#gid=1364025501
# user management - no action
# business productivity - no action
# core infrastructure - no action
# search - no action
# security - no action


########
## project renaming

# collab & DM (Sergio)
run_sync_tool "-m" "flags-page-flags-web-" "flags-web"
run_sync_tool "-m" "notifications-portlet" "notifications-web"
run_sync_tool "-m" "wiki-navigation-portlet" "wiki-navigation-web"
# UI (Chema)
run_sync_tool "-m" "frontend-editors-web" "frontend-editor-lang"

## change the "pretty" project names

#######
## Spreads / merges

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

# almost all - spread from portal impl to all remaining projects
# this covers reported refactorings as well as unreported ones
run_sync_tool "-S" "portal-impl"


########
## Send pull requests to brian
## wait for approval

## run remote_control_api/projects/provision_projects_dummy.sh
## check list against previos result

## run remote_control_api/projects/provision_projects_only_create.sh
## check results - around 64 new projects

## run remote_control_api/sync/sync_master2pootle.sh to update remaining projects
## review results

## tell Josh to notify translators


