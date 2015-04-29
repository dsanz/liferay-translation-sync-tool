function send_email() {
	command="$0 $@";

	echo "Command: $command <br>" > /tmp/body.html
	cat $logfile | $ANSIFILTER_HOME/ansifilter -H -e UTF-8 -w256 -F monospace | sed 's/font-family/background:#000000;font-family/g' >> /tmp/body.html
	rm /tmp/log.tgz > /dev/null 2>&1
	tar czvf /tmp/log.tgz $logbase > /dev/null 2>&1

	$SWAKS_HOME/swaks -t daniel.sanz@liferay.com \
		--from "sync-tool-no-reply@liferay.com" \
		--header "Subject: $product $(date)" \
		--add-header "Content-Type: text/html ; charset=\"UTF-8\"" \
		--add-header "MIME-Version: 1.0" \
		--attach-type "text/html" --attach /tmp/body.html \
		--attach /tmp/log.tgz > /dev/null 2>&1
}
