#!/bin/sh

# Load configuration
#. pootle-manager.conf
# Load common functions
. common-functions.sh

####
## File conversion/management
####
    native_2_ascii() {
	# Convert native2ascii (all files) - If this causes performance
	#  issues then svn output can be catched and parsed to understand
	#  which only files needs to be converted.
	echo_cyan "[`date`] Converting properties files to ascii ..."

	projects=`ls $SVNDIR`
	for project in $projects;
	do
		echo_white "  $project: converting properties to ascii"

		cp $SVNDIR/$project/$FILE.$PROP_EXT $TMP_PROP_IN_DIR/$project
		languages=`ls "$SVNDIR/$project"`
		for language in $languages ; do
			pl="$TMP_PROP_IN_DIR/$project/$language"
			echo -n  "    native2ascii $project/$language "
			[ -f $pl ] && native2ascii -encoding utf8 $pl "$pl.ascii"
			[ -f "$pl.ascii" ] && mv --force "$pl.ascii" $pl
			check_command
		done
	done
    }

    ascii_2_native() {
	echo_cyan "[`date`] Converting properties files to native ..."

	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		echo_white "  $project: converting properties to native"
		#cp -R $PODIR/$project/*.properties $TMP_PROP_OUT_DIR/$project
		languages=`ls "$TMP_PROP_OUT_DIR/$project"`
		for language in $languages ; do
			pl="$TMP_PROP_OUT_DIR/$project/$language"
			echo -n  "    native2ascii $project/$language "
			[ -f $pl ] && native2ascii -reverse -encoding utf8 $pl "$pl.native"
			[ -f "$pl.native" ] && mv --force "$pl.native" $pl
			check_command
		done
	done
    }

    split_automatic_prop() {
	echo_cyan "[`date`] Selecting automatic translations from properties files..."
	regex=".*\(Automatic (Translation|Copy)\)$"
	projects=`ls $TMP_PROP_IN_DIR`
	for project in $projects;
	do
		echo_white "  $project: processing automatic translations"
		languages=`ls "$TMP_PROP_IN_DIR/$project"`
		[ ! -d "$TMP_PROP_IN_DIR/$project/aut" ] && mkdir -p "$TMP_PROP_IN_DIR/$project/aut"
		# uncomment to filter the manual translations
		#[ ! -d "$TMP_PROP_IN_DIR/$project/man" ] && mkdir -p "$TMP_PROP_IN_DIR/$project/man"
		for language in $languages;
		do
			if [ -f $TMP_PROP_IN_DIR/$project/$language ] && [ "$FILE.$PROP_EXT" != "$language" ]; then
				l=`echo $language  | cut -f2- -d _ | cut -f1 -d .`
				echo -n "    grep $project/$language "
				grep -E "$regex" "$TMP_PROP_IN_DIR/$project/$language" > "$TMP_PROP_IN_DIR/$project/aut/$language"
				# grep outputs 1 if no matches are found so check_command will show FAIL when there are no auto translations
				if [ $? != 0 ]; then
					echo -n " [no auto translations detected] "
				else
					echo -n " [auto translations detected] "
				fi
				# uncomment to filter the manual translations
				#grep -v -E "$regex" "$TMP_PROP_IN_DIR/$project/$language" > "$TMP_PROP_IN_DIR/$project/man/$language"
				check_command
			fi
		done
	done
    }

    # $1 - project
    # $2 - language
    refill_automatic_prop() {
	echo "    $1/$2"
	from="$TMP_PROP_OUT_DIR/$1/$2"
	to="$TMP_PROP_OUT_DIR/$1/$2.filled"
	template="$TMP_PROP_OUT_DIR/$1/$FILE.$PROP_EXT"
	orig="$TMP_PROP_IN_DIR/$1/$2"
	svnorig="$TMP_PROP_IN_DIR/$1/svn/$2"
	svnunix="$TMP_PROP_OUT_DIR/$1/$2.unix"

	cp $svnorig $svnunix
	dos2unix $svnunix

	#echo "Readling lines from $from"
	#echo "Checking template file $template"
	#echo "Writing result to $to"
	#echo "Original SVN is $svnorig"
	#echo "UnixSVN is $svnunix"

	[ -f "$to" ] && rm -f "$to"
	script="\
		use strict;\
		my %valuesFromSVN = ();\
		open FILE, '$svnunix';\
		while (my \$line = <FILE>) {\
			if (\$line =~ m/^[^#].+=/) {\
				(my \$key, my \$value) = split(/=/, \$line);\
				\$valuesFromSVN{\$key} = \$line;\
			}\
		}\
		close FILE;\
		my %valuesFromTemplate = ();\
		open FILE, '$template';\
		while (my \$line = <FILE>) {\
			if (\$line =~ m/^[^#].+=/) {\
				(my \$key, my \$value) = split(/=/, \$line);\
				\$valuesFromTemplate{\$key} = \$line;\
			}\
		}\
		close FILE;\
		open FROM, '$from';\
		open TO, '>$to';\
		while (my \$line = <FROM>) {\
			if (\$line =~ m/^[^#].+=/) {\
				(my \$key, my \$value) = split(/=/, \$line);\
				if (\$line eq \$valuesFromTemplate{\$key}) {\
					print TO \$valuesFromSVN{\$key};\
				} else {\
					print TO \$line;\
				}\
			} else {\
				print TO \$line;\
			}\
		}\
		close FROM;\
		close TO;\
		"
	perl -e "$script"
	rm -f $svnunix

	if [ "CRLF" = "`file $svnorig | grep -o CRLF`" ]; then
		unix2dos "$to"
	fi
	mv -f "$to" "$from"
    }

    # gets called after checkout from SVN and before native2ascii
    keep_template() {
	echo_cyan "[`date`] Keeping file templates for later exporting ..."

	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		echo_white "  $project: creating .po file"
		prop2po -i $PODIR/$project/$FILE.$PROP_EXT -o $TMP_PO_DIR/$project/ -P
	done
    }
