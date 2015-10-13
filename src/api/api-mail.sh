function send_email() {
	command="$0 $@";

	logt 1 "Sending email with job details"
	logt 2 "Packaging (this will be the last line included in the package)"
	echo "Command: $command <br>" > /tmp/body.html

	rm /tmp/body.html > /dev/null 2>&1
	rm /tmp/body.html.bz2 > /dev/null 2>&1
	cat $logfile | $ANSIFILTER_BIN -H -e UTF-8 -w256 -F monospace | sed 's/font-family/background:#000000;font-family/g' >> /tmp/body.html

	rm /tmp/log.tar.bz2 > /dev/null 2>&1
	rm /tmp/log.tar > /dev/null 2>&1
	tar cvf /tmp/log.tar $logbase > /dev/null 2>&1

	bzip2 /tmp/log.tar
	bzip2 /tmp/body.html

	logt 2 -n "Sending "
	$SWAKS_BIN -t daniel.sanz@liferay.com \
		--from "sync-tool-no-reply@liferay.com" \
		--header "Subject: ($LR_TRANS_MGR_PROFILE) $product $(date)" \
		--add-header "Content-Type: text/html ; charset=\"UTF-8\"" \
		--add-header "MIME-Version: 1.0" \
		--body "Sync Tool execution: $command" \
		--attach-type "text/html" --attach /tmp/body.html.bz2 \
		--attach /tmp/log.tar.bz2 > /dev/null 2>&1
	check_command
}
