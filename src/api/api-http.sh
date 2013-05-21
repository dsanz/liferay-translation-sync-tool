#!/bin/bash

function close_pootle_session() {
	# get logout page and delete cookies
	echo -n "      Closing pootle session... "
	curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" "$PO_SRV/accounts/logout" > /dev/null
	check_command
}

function start_pootle_session() {
	echo "      First, access logout page from pootle"
	close_pootle_session
	# 1. get login page (and cookies)
	echo -n "      Accessing Pootle login page... "
	curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" "$PO_SRV/accounts/login" > /dev/null
	check_command
	# 2. post credentials, including one received cookie
	echo -n "      Authenticating as $PO_USER ... "
	curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" -d "username=$PO_USER;password=$PO_PASS;csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" "$PO_SRV/accounts/login" > /dev/null
	check_command
}