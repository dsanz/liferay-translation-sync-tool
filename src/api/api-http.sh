#!/bin/bash

function close_pootle_session() {
	# get logout page and delete cookies
	logt 3 -n "Closing pootle session... "
	curl $CURL_OPTS "$PO_SRV/accounts/logout"
	check_command
}

function start_pootle_session() {
	close_pootle_session
	# 1. get login page (and cookies)
	logt 3 -n "Accessing Pootle login page... "
	curl $CURL_OPTS "$PO_SRV/accounts/login"
	check_command
	# 2. post credentials, including one received cookie
	logt 3 -n "Authenticating as '$PO_USER' "
	curl $CURL_OPTS -d "username=$PO_USER;password=$PO_PASS;csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" "$PO_SRV/accounts/login"
	check_command
}

function is_pootle_server_up() {
	wget -q --delete-after $PO_SRV
}