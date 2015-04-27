function send_email() {
	logfile=$1;
	command="$0 $@";

	(echo "From: sync-tool-no-reply@liferay.com";
	echo "To: daniel.sanz@liferay.com";
	echo "Subject: $product $(date)";
	echo "MIME-Version: 1.0" ;
	echo "Content-Type: text/html;charset=\"UTF-8\"" ;
	echo "Content-Transfer-Encoding: quoted-printable";
	echo "Command: $command"
	echo "Log: ";
	cat $logfile)|sendmail -t
}