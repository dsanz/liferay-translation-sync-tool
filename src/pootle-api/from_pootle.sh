#!/bin/bash


## basic functions

# creates temporary working dirs for working with pootle output
function prepare_output_dirs() {
	echo_cyan "[`date`] Preparing project output working dirs..."
	for (( i=0; i<${#PROJECT_NAMES[@]}; i++ ));
	do
		project=${PROJECT_NAMES[$i]}
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
	for (( i=0; i<${#PROJECT_NAMES[@]}; i++ ));
	do
		project=${PROJECT_NAMES[$i]}
		echo_white "  $project"
		echo -n "    Synchronizing pootle stores for all languages "
		# Save all translations currently in database to the file system
		$POOTLEDIR/manage.py sync_stores --project="$project" -v 0 > /dev/null 2>&1
		check_command
		echo "    Copying exported tranlsations into working dir"
		echo -n "       "
		for language in $(ls "$PODIR/$project"); do
		    echo -n  "$(get_locale_from_file_name $language) "
    		cp -f  "$PODIR/$project/$language" "$TMP_PROP_OUT_DIR/$project/"
		done
	    echo
	done
}

## File processing functions

# Pootle exports its translations into ascii-encoded properties files. This converts them to UTF-8
function ascii_2_native() {
	echo_cyan "[`date`] Converting properties files to native ..."

	for (( i=0; i<${#PROJECT_NAMES[@]}; i++ ));
	do
		project=${PROJECT_NAMES[$i]}
		echo_white "  $project: converting working dir properties to native"
		#cp -R $PODIR/$project/*.properties $TMP_PROP_OUT_DIR/$project
		languages=`ls "$TMP_PROP_OUT_DIR/$project"`
		for language in $languages ; do
			pl="$TMP_PROP_OUT_DIR/$project/$language"
			echo -n  "$(get_locale_from_file_name $language) "
			[ -f $pl ] && native2ascii -reverse -encoding utf8 $pl "$pl.native"
			[ -f "$pl.native" ] && mv --force "$pl.native" $pl
		done
		check_command
	done
}

# Pootle exports all untranslated keys, assigning them the english value. This function restores the values in old version of Language_*.properties
# this way, untranslated keys will have the Automatic Copy/Translation tag
function process_untranslated() {
	echo_cyan "[`date`] Processing untranslated keys"
	for (( i=0; i<${#PROJECT_NAMES[@]}; i++ ));
	do
		project=${PROJECT_NAMES[$i]}
		echo_white "  $project"
		languages=`ls $PODIR/$project`
        echo_yellow "    Setting up log file"
        check_dir "$logbase/$project/"
        echo_yellow "    Reading template file"
        read_pootle_exported_template $project
		for language in $languages; do
		    echo_yellow "    Reading $language file"
            read_pootle_exported_language_file $project $language
			echo_yellow "    Reading $language file from source branch (at last commit uploaded to pootle)"
            read_previous_language_file $project $language
			echo_yellow "    Reading overriding translations"
            read_ext_language_file $project $language
            refill_translations $project $language
            locale=$(get_locale_from_file_name $language)
            clear_keys "$(get_exported_language_prefix $project $locale)"
            clear_keys "$(get_previous_language_prefix $project $locale)"
		done
	done
}

function is_from_template() {
    project="$1"
    locale="$2"
    key="$3"
    templatePrefix=$(get_template_prefix $project $locale)
    exportedPrefix=$(get_exported_language_prefix $project $locale)
    ! $(value_changed $templatePrefix $exportedPrefix $key)
}

# Due to pootle exports all untranslated keys, there is no way to know if a value in Language_xx.properties
# comes from an untranslated keys or a key which valid value in that language is the same than english.
# This distinction is crucial to skip auto translating terms which are better known if the english word is used.
# For example: "staging" is used in Spanish to denote "Staging".
# In order to know this, direct access to Pootle DB is needed
function refill_translations() {
    set -f
    project="$1";
    language="$2";
    locale=$(get_locale_from_file_name $language)

    # required by api-db to access pootle DB in case we need to know if a term was translated using the english word or not
    storeId=$(get_store_id $project $locale)
    path=$(get_pootle_path $project $locale)

    # involved file paths
    srcfile=$(get_project_language_path $project)/$language
    workingfile=$(srcfile)/$language.final
    logfile="$logbase/$project/$language"
    rm $workingfile # when debugging we don't run all sync stages so we can have this file from a previous run
    target_lang_path="$TMP_PROP_OUT_DIR/$project/$language"

    # prefixes for array accessing
	exportedPrefix=$(get_exported_language_prefix $project $locale)
    previousPrefix=$(get_previous_language_prefix $project $locale)
    templatePrefix=$(get_template_prefix $project $locale)
    extPrefix=$(get_ext_language_prefix $project $locale)

    echo_yellow "    Copying translations: 'p' from pootle.  'x' conflict, pootle wins, please review logs.  '·' same valid translation in pootle and master.  'o' overriden from ext.  'e' English is ok.  'u' untranslated, pick old commit.  'r' reverse-path (sources translated, pootle not).  'a' to be translated by ant.  '#' comment.  '!' uncovered case)"
    declare -A R  # referse translations
    declare -A C  # conflicts
    while read line; do
	    char="!"
		if is_key_line "$line" ; then
			[[ "$line" =~ $kv_rexp ]] && key="${BASH_REMATCH[1]}"
			if exists_ext_value $extPrefix $key; then                       # has translation to be overriden?
			    value=$(getTVal $extPrefix $key)
			    char="o"
			elif is_from_template $project $locale $key; then               # otherwise, is the exported value equals to the template?
			    targetf=$(get_targetf $storeId $key)
			    valueTpl=$(getTVal $templatePrefix $key)
			    if [[ "$targetf" == "$value" ]]; then                       #   then, was it translated that way on purpose?
			        char="e"                                                #       use the template value
			        value=$valueTpl
			    else                                                        #   otherwise, key is really untranslated in pootle
			        valuePrev=$(getTVal $previousPrefix $key)               #       get the translation from master, current commit (or previous??)
			        if is_translated_value "$valuePrev"; then               #       is the key translated in master? shouldn't happen unless we have an auto-translation
			            if [[ "$valuePrev" != "$valueTpl" ]]; then          #           is the value in master different from the template?
                            char="r"
                            value=$valuePrev
                            R[$key]="$value"
			            else                                                #           ok, value in master is just like the template
                            char="a"                                        #               discard it! ant build-lang will do
                    	    value=""
                    	fi
			        else
			            char="u"                                            #        otherwise, it's auto-translated: reuse it, don't do same work twice
			            value=$valuePrev
			        fi;
			    fi
			else
			    value=$(getTVal $exportedPrefix $key)                       #   otherwise, it's supposed to be a valid translation
		        valuePrev=$(getTVal $previousPrefix $key)                   #   get the translation from master, current commit (or previous??)
                if is_translated_value "$valuePrev"; then                   #   was the master value translated
                    if [[ "$valuePrev" != "$value" ]]; then                 #       is this translation different than the one pootle exported?
                        char="x"                                            #           conflict, pootle wins. Let user know
                        C[$key]="$value"                                    #           take note of itfor logging purposes
                    else
                        char="·"                                            #       no-op, already translated both in pootle and master
                    fi
                else                                                        # the master value is auto-translated/auto-copied
                    char="p"                                                #   translated in pootle, but not in master. OK!!
                fi
			fi
			result="${key}=${value}"
		else                                                               # is it a comment line?
			char="#"
			result=$line                                                   #    get the whole line
		fi
		echo "$result" >> $workingfile
		echo "[${char}]___${result}" >> $logfile
		echo -n $char
	done < $target_lang_path

    echo
    if [[ ${#R[@]} -gt 0 ]]; then
        echo_yellow "    Submitting translations from master to pootle. Next time be sure to run this manager with -p option!"
        start_pootle_session
        for key in "${!R[@]}"; do
            value=${R[$key]}
            upload_submission "$key" "$value" "$storeId" "$path"
	    done;
	    close_pootle_session
    fi
    if [[ ${#C[@]} -gt 0 ]]; then
        echo_yellow "    Conflicts are keys having correct, different translations both in pootle and in sources. Please check following keys:"
        for key in "${!C[@]}"; do
            echo -n "$key "
	    done;
    fi
	set +f
	unset R
	unset C
	mv $workingfile $srcfile
}

function exists_ext_value() {
    extPrefix=$1
    key=$2
    exists_key $extPrefix $key
}

# given a project and a language, reads the Language_xx.properties file
# exported from pootle and puts it into array T using the locale as prefix
function read_ext_language_file() {
    project="$1";
    language="$2";
    locale=$(get_locale_from_file_name $language)
    langFile="conf/ext/$project/$language"
	if [ -e $langFile ]; then
        prefix=$(get_ext_language_prefix $project $locale)
	    read_locale_file $langFile $prefix
	fi
}

function get_ext_language_prefix() {
    echo "x$1$2"
}

# given a project, reads the Language.properties file exported from pootle
# and puts it into array T using the project as prefix
function read_pootle_exported_template() {
    project="$1";
    template="$TMP_PROP_OUT_DIR/$project/$FILE.$PROP_EXT"
	prefix=$(get_template_prefix $project $locale)
	read_locale_file $template $prefix true
}

function get_template_prefix() {
    echo $1
}

# given a project and a language, reads the Language_xx.properties file
# exported from pootle and puts it into array T using the locale as prefix
function read_pootle_exported_language_file() {
    project="$1";
    language="$2";
    locale=$(get_locale_from_file_name $language)
    langFile="$TMP_PROP_OUT_DIR/$project/$language"
	prefix=$(get_exported_language_prefix $project $locale)
	read_locale_file $langFile $prefix
}

function get_exported_language_prefix() {
    echo $1$2
}

# given a project and a language, reads the Language_xx.properties file
# from the branch and puts it into array T using "p"+locale as prefix
function read_previous_language_file() {
    project="$1";
    language="$2";
    locale=$(get_locale_from_file_name $language)
    sources=$(get_project_language_path $project)
    langFile="$sources/$language"
    git checkout $LAST_BRANCH > /dev/null 2>&1   # just in case we have run with -p. Now we are in the las update branch
	prefix=$(get_previous_language_prefix $project $locale)
	read_locale_file $langFile $prefix
}

function get_previous_language_prefix() {
    echo "p$1$2"
}
