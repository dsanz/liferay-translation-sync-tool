function provision_projects_action() {
	read_projects_from_sources
	provision_projects true true
}

function provision_projects_only_create_action() {
	read_projects_from_sources
	provision_projects true false
}

function provision_projects_only_delete_action() {
	read_projects_from_sources
	provision_projects false true
}

function provision_projects_dummy_action() {
	read_projects_from_sources
	provision_projects false false
}