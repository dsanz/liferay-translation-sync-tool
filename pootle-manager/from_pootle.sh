#!/bin/bash

. common-functions.sh

####
## Pootle server communication - from pootle
####

## basic functions

# creates temporary working dirs for working with pootle output
function prepare_output_dirs() {
	echo_cyan "[`date`] Preparing project output working dirs..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		echo_white "  $project: cleaning output working dirs"
		clean_dir "$TMP_PROP_OUT_DIR/$project"
		clean_dir "$TMP_PO_DIR/$project"
	done
}

# moves files from working dirs to its final destination, making them ready for committing
function prepare_vcs() {
	echo_cyan "[`date`] Preparing processed files to VCS dir for commit..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		languages=`ls $PODIR/$project`
		echo_white "  $project: processing files"
		for language in $languages; do
			if [ "$FILE.$PROP_EXT" != "$language" ] ; then
				echo_yellow "    $project/$language: "
				check_command
			fi
		done
	done
}


## Pootle communication functions

# tells pootle to export its translations to properties files inside webapp dirs
function update_pootle_files() {
	echo_cyan "[`date`] Updating pootle files from pootle DB..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		echo_white "  $project: synchronizing pootle stores for all locales"
		# Save all translations currently in database to the file system
		$POOTLEDIR/manage.py sync_stores --project="$project" -v 0
	done
}

## File processing functions

# saves a .po file from the Language.properties file stored by pootle inside webapps dirs
# gets called before native2ascii
function keep_template() {
	echo_cyan "[`date`] Keeping file templates for later exporting ..."

	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		echo_white "  $project: creating .pot file from Language.properties"
		prop2po -i $PODIR/$project/$FILE.$PROP_EXT -o $TMP_PO_DIR/$project/ -P --progress=none
		check_command
		echo "      Created $(ls $TMP_PO_DIR/$project/) file"
	done
}

# reformats .properties files by generating a .po, then a new .properties from that .po and the template .po
function reformat_pootle_files() {
	echo_cyan "[`date`] Reformatting exported pootle files..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		languages=`ls $PODIR/$project`
		echo_white "  $project: reformatting files"
		clean_dir "$TMP_PROP_OUT_DIR/$project"
		for language in $languages; do
			if [ "$language" != "$FILE.$PROP_EXT" ]; then
				echo_yellow "    $project/$language "
				lang=`echo $language  | cut -f2- -d _ | cut -f1 -d .`
				echo -n "      Original ${FILE}_$lang.$PROP_EXT --> ${FILE}_$lang.$PO_EXT "
				prop2po -i "$PODIR/$project/$language" -o "$TMP_PO_DIR/$project/" -t "$PODIR/$project/$FILE.$PROP_EXT" --progress=none
				check_command
				echo -n "      ${FILE}_$lang.$PO_EXT --> formatted ${FILE}_$lang.$PROP_EXT"
				po2prop -i "$TMP_PO_DIR/$project/${FILE}_$lang.$PO_EXT" -o "$TMP_PROP_OUT_DIR/$project/" -t "$PODIR/$project/$FILE.$PROP_EXT" --progress=none
				check_command
			fi
		done
		echo_white "  $project: copying Language.properties file into working dir"
		cp -f "$PODIR/$project/$FILE.$PROP_EXT" "$TMP_PROP_OUT_DIR/$project/"
	done
}

# Pootle exports its translations into ascii-encoded properties files. This converts them to UTF-8
function ascii_2_native() {
	echo_cyan "[`date`] Converting properties files to native ..."

	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		echo_white "  $project: converting working dir properties to native"
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

# Pootle exports all untranslated keys, assigning them the english value. This function restores the values in old version of Language_*.properties
# this way, untranslated keys will have the Automatic Copy/Translation tag
function add_untranslated() {
	echo_cyan "[`date`] Adding automatic translations to untranslated entries..."
	projects_count=$((${#PROJECTS[@]} - 1))
	for i in `seq 0 $projects_count`;
	do
		project=`echo ${PROJECTS[$i]}| cut -f1 -d ' '`
		languages=`ls $PODIR/$project`
		[ ! -d "$TMP_PROP_OUT_DIR/$project" ] && mkdir -p "$TMP_PROP_OUT_DIR/$project"
		echo_white "  $project: refilling untranslated entries"
		for language in $languages; do
			refill_automatic_prop $project $language
		done
	done
}

# refills all untranslated keys with the value in a previous file.
# this way, untranslated keys will have the Automatic Copy/Translation tag
# $1 - project
# $2 - language
function refill_automatic_prop() {
	echo "    $1/$2"
	from="$TMP_PROP_OUT_DIR/$1/$2"
	to="$TMP_PROP_OUT_DIR/$1/$2.filled"
	template="$TMP_PROP_OUT_DIR/$1/$FILE.$PROP_EXT"
	orig="$TMP_PROP_IN_DIR/$1/$2"
	src_orig="$TMP_PROP_IN_DIR/$1/svn/$2"
	src_unix="$TMP_PROP_OUT_DIR/$1/$2.unix"

	cp $src_orig $src_unix
	dos2unix $src_unix

	[ -f "$to" ] && rm -f "$to"
	script="\
		use strict;\
		my %valuesFromLang = ();\
		open FILE, '$src_unix';\
		while (my \$line = <FILE>) {\
			if (\$line =~ m/^[^#].+=/) {\
				(my \$key, my \$value) = split(/=/, \$line);\
				\$valuesFromLang{\$key} = \$line;\
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
					print TO \$valuesFromLang{\$key};\
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
	rm -f $src_unix

	if [ "CRLF" = "`file $src_orig | grep -o CRLF`" ]; then
		unix2dos "$to"
	fi
	mv -f "$to" "$from"
}
