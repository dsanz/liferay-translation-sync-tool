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
        echo_yellow "    Reading template file"
        read_pootle_exported_template $project
		for language in $languages; do
		    echo_yellow "    Reading $language file"
            read_pootle_exported_language_file $project $language
			echo_yellow "    Reading $language file from source branch (at last commit uploaded to pootle)"
            read_previous_language_file $project $language
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
    project="$1";
    language="$2";
    locale=$(get_locale_from_file_name $language)
    file=$(get_project_language_path $project)/$language.final
    rm $file
    target_lang_path="$TMP_PROP_OUT_DIR/$project/$language"
	exportedPrefix=$(get_exported_language_prefix $project $locale)
    previousPrefix=$(get_previous_language_prefix $project $locale)
    templatePrefix=$(get_template_prefix $project $locale)
    storeId=$(get_store_id $project $locale)
    while read line; do
	    char="x"
		if is_key_line "$line" ; then
			[[ "$line" =~ $kv_rexp ]] && key="${BASH_REMATCH[1]}"
			if is_from_template $project $locale $key; then                 # is the exported value equals to the template?
			    targetf=$(get_targetf $storeId $key)
			    if [[ $targetf == $(getTVal $templatePrefix $key) ]]; then  #   then, was it translated that way on purpose?
			        value=targetf                                           #       grab the translation
			        char="e"
			    else                                                        #       otherwise, key is really untranslated in pootle
			        value=$(getTVal $previousPrefix $key)                   #           get the translation from master
			        if is_translated_value $value; then                     #           is not auto-translated?
                        char="-"                                            #               discard it! ant build-lang will do
                    	value=""
			        else
			            char="o"                                            #           otherwise, reuse it, don't do same work twice
			        fi;
			    fi
			else
			    value=$(getTVal $exportedPrefix $key)                       #   otherwise, it's supposed to be a valid translation
			    char="."
			fi
			result="${key}=${value}"
		else
			char="#"
			result=$line
		fi
		echo "$result" >> $file
		echo -n $char
	done < $target_lang_path
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
    echo "$1$2"
}

# given a project and a language, reads the Language_xx.properties file
# from the branch and puts it into array T using "p"+locale as prefix
function read_previous_language_file() {
    project="$1";
    language="$2";
    locale=$(get_locale_from_file_name $language)
    sources=$(get_project_language_path $project)
    langFile="$sources/$language"
    #be sure we are in the correct branch
	prefix=$(get_previous_language_prefix $project $locale)
	read_locale_file $langFile $prefix
}

function get_previous_language_prefix() {
    echo "p$1$2"
}
