
function exists_project_in_pootle() {
	wget --spider "$PO_SRV/projects/$1" 2>&1 | grep 200 > /dev/null
}

function get_pootle_projects() {

}

