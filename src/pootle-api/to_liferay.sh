#!/bin/bash


## basic functions

function prepare_output_dir() {
	project="$1"
	logt 2 "$project: cleaning output working dirs"
	clean_dir "$TMP_PROP_OUT_DIR/$project"
}

# creates temporary working dirs for working with pootle output
function clean_temp_output_dirs() {
	logt 1 "Preparing project output working dirs..."
	logt 2 "Cleaning general output working dirs"
	clean_dir "$TMP_PROP_OUT_DIR/"
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		prepare_output_dir "$project"
	done
}

function pull_source_code() {
	logt 1 "Preparing project source dirs..."
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		goto_branch_tip "$base_src_dir"
	done;
}

function do_commit() {
	reuse_branch=$1
	submit_pr=$2
	commit_msg=$3
	logt 1 "Committing results (reusing branch?=${reuse_branch}, will submit pr?=$submit_pr)"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		cd $base_src_dir
		logt 2 "$base_src_dir"

		logt 3 "Adding untracked files"
		added_language_files=$(git status -uall --porcelain | grep "??" | grep $FILE | cut -f 2 -d' ')
		if [[ $added_language_files != "" ]]; then
			for untracked in $added_language_files; do
				logt 4 -n "git add $untracked"
				git add "$untracked"
				check_command
			done
		else
			logt 4 "No untracked files to add"
		fi;
		if something_changed; then
			if exists_branch "$EXPORT_BRANCH" "$base_src_dir"; then
				if $reuse_branch; then
					logt 3 "Reusing export branch"
					logt 4 -n "git checkout $EXPORT_BRANCH"
					git checkout "$EXPORT_BRANCH" > /dev/null 2>&1
					check_command
					create_branch=false;
				else
					logt 3 "Deleting old export branch"
					logt 4 -n "git branch -D $EXPORT_BRANCH"
					git branch -D "$EXPORT_BRANCH" > /dev/null 2>&1
					check_command
					create_branch=true;
				fi
			else
				create_branch=true;
			fi

			if $create_branch; then
				sync_branch="${GIT_ROOTS["$base_src_dir"]}"
				logt 3 "Creating new export branch from $sync_branch"
				logt 4 -n "git checkout $sync_branch"
				git checkout $sync_branch > /dev/null 2>&1
				check_command
				logt 4 -n "git checkout -b $EXPORT_BRANCH"
				git checkout -b "$EXPORT_BRANCH" > /dev/null 2>&1
				check_command
			fi
			msg="$LPS_CODE $commit_msg [by $product]"
			logt 3 "Committing..."
			logt 4 -n "git commit -a -m $msg"
			git commit -a -m "$msg" > /dev/null 2>&1
			check_command
		else
			logt 3 "No changes to commit!!"
		fi
		if $submit_pr; then
			submit_pull_request $base_src_dir
		fi
	done;
}

function submit_pull_request() {
	base_src_dir="$1"
	logt 3 -n "Deleting remote branch origin/$EXPORT_BRANCH"
	git push origin ":$EXPORT_BRANCH" > /dev/null 2>&1
	check_command

	logt 3 -n "Pushing remote branch origin/$EXPORT_BRANCH"
	git push origin "$EXPORT_BRANCH" > /dev/null 2>&1
	check_command

	reviewer="${PR_REVIEWER[$base_src_dir]}"
	sync_branch="${GIT_ROOTS[$base_src_dir]}"
	logt 3 -n "Sending pull request to $reviewer:$sync_branch"
	pr_url=$($HUB_BIN pull-request -m "Translations from pootle. Automatic PR sent by $product" -b "$reviewer":"$sync_branch" -h $EXPORT_BRANCH)
	check_command

	logt 4 "Pull request URL: $pr_url"

	logt 3 -n "git checkout $sync_branch"
	git checkout $sync_branch > /dev/null 2>&1
	check_command
}

function ant_all() {
	if [[ "${LR_TRANS_MGR_PROFILE}" == "dev" ]]; then
		logt 1 "Skipping ant all as we are in dev environment."
		return;
	fi;

	logt 1 "Running ant all for portal"
	logt 3 -n "cd $SRC_PORTAL_BASE"
	cd ${SRC_PORTAL_BASE}
	check_command
	ant_log_dir="$logbase/$PORTAL_PROJECT_ID"
	ant_log="$ant_log_dir/ant-all.log"
	check_dir $ant_log_dir
	logt 2 -n "$ANT_BIN all (all output redirected to $ant_log)"
	$ANT_BIN all > "$ant_log" 2>&1
	check_command
}

function build_lang() {
	ant_all
	logt 1 "Running ant build-lang"
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		ant_dir="${AP_PROJECT_BUILD_LANG_DIR[$project]}"
		logt 2 "$project"
		logt 3 -n "cd $ant_dir"
		cd $ant_dir
		check_command
		ant_log="$logbase/$project/ant-build-lang.log"
		logt 3 -n "$ANT_BIN build-lang (all output redirected to $ant_log)"
		$ANT_BIN build-lang > "$ant_log" 2>&1
		check_command

		# this checks if ant build-lang tell us to run gradlew buildLang
		logt 2 "Checking if ant redirects to gradle"
		invocation=$(cat "$ant_log" | grep "instead" | sed -r 's/[^:]+: (.*)$/\1/g')
		if [[ $invocation == *"gradle"* ]]; then
			gradle_log="$logbase/$project/gradle-build-lang.log"
			logt 3 "Running '$invocation' (all output redirected to $gradle_log)"
			$invocation > $gradle_log 2>&1
			check_command
		fi
	done;
}

## Pootle communication functions

function sync_stores() {
	project="$1"
	logt 2 "Synchronizing pootle stores for all languages ($project) "
	check_dir "$PODIR/$project"
	# Save all translations currently in database to the file system
	call_manage "sync_stores" "--project=$project" "-v 0" "--overwrite"
}

function export_pootle_project_translations_to_temp_dirs() {
	project="$1"
	regenerate_stores $project
	logt 3 "Copying exported translations into working dir"

	# here we need the actual contents in $PODIR/$project instead of the locale set
	for language in $(ls "$PODIR/$project"); do
		if [[ "$language" =~ $lang_file_rexp ]]; then
			logt 0 -n  "$(get_locale_from_file_name $language) "
			cp -f  "$PODIR/$project/$language" "$TMP_PROP_OUT_DIR/$project/"
		fi
	done
	check_command
}

# tells pootle to export its translations to properties files to $PODIR dir
function export_pootle_translations_to_temp_dirs() {
	logt 1 "Updating pootle files from pootle DB..."
	read_pootle_projects_and_locales
	for project in "${POOTLE_PROJECT_CODES[@]}"; do
		export_pootle_project_translations_to_temp_dirs "$project"
	done
}

## File processing functions

# Pootle exports its translations into ascii-encoded properties files. This converts them to UTF-8
function ascii_2_native() {
:
}
function ascii_2_native_orig() {
	logt 1 "Converting properties files to native ..."
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		logt 2 "$project: converting working dir properties to native"
		languages=`ls "$TMP_PROP_OUT_DIR/$project"`
		for language in $languages ; do
			if [[ "$language" =~ $trans_file_rexp ]]; then
				pl="$TMP_PROP_OUT_DIR/$project/$language"
				logt 0 -n "$(get_locale_from_file_name $language) "
				[ -f $pl ] && NATIVE2ASCII_BIN -reverse -encoding utf8 $pl "$pl.native"
				[ -f "$pl.native" ] && mv --force "$pl.native" $pl
			fi
		done
		check_command
	done
}

function process_project_translations() {
	project="$1"
	publish_translations="$2"
	languages=`ls $PODIR/$project`
	logt 2 "$project"
	logt 3 "Setting up per-project log file"
	check_dir "$logbase/$project/"
	logt 3 "Reading template file"
	read_pootle_exported_template $project
	for language in $languages; do
		locale=$(get_locale_from_file_name $language)
		if [[ "$locale" != "en" && "$language" =~ $trans_file_rexp ]]; then
			logt 2 "$project: $locale"
			logt 3 "Reading $language file"
			read_pootle_exported_language_file $project $language
			logt 3 "Reading $language file from source code branch (just pulled)"
			read_previous_language_file $project $language
			logt 3 "Reading pootle store"
			read_pootle_store $project $language
			logt 3 "Reading overriding translations"
			read_ext_language_file $project $language
			refill_translations $project $language $publish_translations
			logt 3 -n "Garbage collection... "
			clear_keys "$(get_exported_language_prefix $project $locale)"
			clear_keys "$(get_previous_language_prefix $project $locale)"
			clear_keys "$(get_store_language_prefix $project $locale)"
			clear_keys "$(get_ext_language_prefix $project $locale)"
			check_command
		fi
	done
	logt 3 -n "Garbage collection (whole project)... "
	unset K
	unset T
	declare -gA T;
	declare -ga K;
	check_command
}


# Pootle exports all untranslated keys, assigning them the english value. This function restores the values in old version of Language_*.properties
# this way, untranslated keys will have the Automatic Copy/Translation tag
function process_translations() {
	logt 1 "Processing translations"
	logt 2 "Legend:"
	unset charc
	unset chart
	declare -gA charc # colors
	declare -gA chart # text legend
	charc["!"]=$RED; chart["!"]="uncovered case"
	charc["o"]=$WHITE; chart["o"]="overriden from ext file"
	charc["e"]=$RED; chart["e"]="English value is ok, was translated on purpose using Pootle"
	charc["r"]=$YELLOW; chart["r"]="reverse-path (sources translated, pootle is untranslated). Will be published to Pootle"
	charc["a"]=$CYAN; chart["a"]="ant build-lang will do (sources and pootle untranslated)"
	charc["u"]=$BLUE; chart["u"]="untranslated, pick existing source value (Pootle untranslated, source auto-translated or auto-copied)"
	charc["x"]=$LILA; chart["x"]="conflict/improvement Pootle wins (pootle and sources translated, different values). Review $copyingLogfile "
	charc["·"]=$COLOROFF; chart["·"]="no-op (same, valid translation in pootle and sources)"
	charc["p"]=$GREEN; chart["p"]="valid translation coming from pootle, sources untranslated"
	charc["#"]=$COLOROFF; chart["#"]="comment/blank line"
	for char in ${!charc[@]}; do
		loglc 8 ${charc[$char]} "'$char' ${chart[$char]}.  "
	done;

	for project in "${!AP_PROJECT_NAMES[@]}"; do
		process_project_translations $project true
	done
}

function dump_store() {
	project="$1";
	language="$2";
	langFile="$3";
	locale=$(get_locale_from_file_name $language)
	storeId=$(get_store_id $project $locale)
	logt 4 "Dumping store id $storeId into $langFile"
	export_targets "$storeId" "$langFile"
}

function read_pootle_store() {
	project="$1";
	language="$2";
	langFile="$TMP_PROP_OUT_DIR/$project/$language.store"
	dump_store "$project" "$language" "$langFile"
	prefix=$(get_store_language_prefix $project $locale)
	read_locale_file $langFile $prefix $3
}

function get_store_language_prefix() {
	echo "s$1$2"
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
	publish_translations="$3"
	locale=$(get_locale_from_file_name $language)

	# required by api-db to access pootle DB in case we need to know if a term was translated using the english word or not
	storeId=$(get_store_id $project $locale)
	local path=$(get_pootle_path $project $locale)

	# involved file paths
	srcfile="${AP_PROJECT_SRC_LANG_BASE["$project"]}/$language"
	workingfile="${srcfile}.final"
	copyingLogfile="$logbase/$project/$language"
	conflictsLogPootle="$logbase/$project/$language.conflicts.pootle"
	conflictsLogLiferay="$logbase/$project/$language.conflicts.liferay"

	[[ -f $workingfile ]] && rm $workingfile # when debugging we don't run all sync stages so we can have this file from a previous run
	target_lang_path="$TMP_PROP_OUT_DIR/$project/$language"

	# prefixes for array accessing
	exportedPrefix=$(get_exported_language_prefix $project $locale)
	previousPrefix=$(get_previous_language_prefix $project $locale)
	templatePrefix=$(get_template_prefix $project $locale)
	storePrefix=$(get_store_language_prefix $project $locale)
	extPrefix=$(get_ext_language_prefix $project $locale)

	declare -A R  # reverse translations
	declare -A Cp  # conflicts - pootle value
	declare -A Cl  # conflicts - liferay source value

	logt 3 "Copying translations..."
	logt 0
	done=false;
	format="%s\n";
	OLDIFS=$IFS
	IFS=
	until $done; do
		if ! read -r line; then
			done=true;
			format="%s"
		fi;
		if [ ! "$line" == "" ]; then
			char="!"
			if is_key_line "$line" ; then
				[[ "$line" =~ $kv_rexp ]] && key="${BASH_REMATCH[1]}" && value="${BASH_REMATCH[2]}"
				valueTpl=${T["$templatePrefix$key"]}
				valueExp=${T["$exportedPrefix$key"]}                            # get translation exported by pootle

				if exists_ext_value $extPrefix $key; then                       # has translation to be overriden?
					value=$(getTVal $extPrefix $key)
					char="o"
				elif [[ "$valueExp" == "$valueTpl" ]]; then                     # ok, no overriding. Now, is exported value = template value?
					valueStore=${T["$storePrefix$key"]}                         #   then let's see if translators wrote the template value by hand in the text box
					if [[ "$valueStore" == "$valueTpl" ]]; then                 #   was it translated that way on purpose?
						char="e"                                                #       use the template value. English is ok in this case.
						value=$valueTpl
					else                                                        #   otherwise, key is really untranslated in pootle
						valuePrev=${T["$previousPrefix$key"]}                   #       let's look for the current key translation in master
						if is_translated_value "$valuePrev"; then               #       is the key translated in master? [shouldn't happen unless we run -r before a -p]
							if [[ "$valuePrev" != "$valueTpl" ]]; then          #           ok, key is already translated in master. is that value different from the template?
								char="r"                                        #               ok, then master is translated but Pootle not, hmmm! we have a reverse-path
								value="$valuePrev"                              #               let's keep`the value in master as a good default.
								R[$key]="$value";                               #               and memorize it so that Pootle can be properly updated later
							else                                                #           ok, value in master is just like the template
								char="a"                                        #               discard it! ant build-lang will do
								value=""
							fi
						else                                                    #       value in master is not translated. This means an auto-copy or auto-translation
							char="u"                                            #           let's reuse it, we are saving build-lang work. don't do same work twice
							value=$valuePrev
						fi;
					fi
				else                                                            # ok, no overriding, and value is not the english one: it's supposed to be a valid translation!!
					value=${T["$exportedPrefix$key"]}                           #   get translation exported by pootle
					valuePrev=${T["$previousPrefix$key"]}                       #   get the translation from master
					if is_translated_value "$valuePrev"; then                   #   is the master value translated?
						if [[ "$valuePrev" != "$value" ]]; then                 #      is this translation different than the one pootle exported?
							char="x"                                            #           ok, we have a conflict, pootle wins. Let user know
							Cp[$key]="$value"                                   #           take note for logging purposes
							Cl[$key]="$valuePrev"
						else                                                    #      ok, translation in master is just like the exported by pootle.
							char="·"                                            #           no-op, already translated both in pootle and master
						fi
					else                                                        #   master value is NOT translated but auto-translated/auto-copied
						char="p"                                                #      ok, translated in pootle, but not in master. OK!!
					fi
				fi
				result="${key}=${value}"
			else                                                               # is it a comment line?
				char="#"
				result="$line"                                                 #    get the whole line
			fi
			printf "$format" "$result" >> $workingfile
			printf "$format"  "[${char}]___${key}" >> $copyingLogfile
			loglc 0 "${charc[$char]}" -n "$char"
		fi;
	done < $target_lang_path
	IFS=$OLDIFS

	logt 0
	if [[ "$publish_translations" == true ]]; then
		if [[ ${#R[@]} -gt 0 ]];  then
			logt 3 "Submitting translations from source to pootle. Next time be sure to run this manager with -p option!"
			start_pootle_session
			for key in "${!R[@]}"; do
				value="${R[$key]}"
				upload_submission "$key" "$value" "$storeId" "$path"
			done;
			close_pootle_session
		fi
	else
		logt 3 "Translation submission is disabled"
	fi;
	if [[ ${#Cp[@]} -gt 0 ]]; then
		logt 3 "Conflicts warning:"
		logt 4 "Conflicts are keys having correct, different translations both in pootle and in liferay sources. During pootle2src, the pootle value will be considered the correct one"
		logt 4 "Please compare contents of following files:"
		logt 5 "$conflictsLogPootle"
		logt 5 "$conflictsLogLiferay"
		logt 4 -n "Generating conflict files"
		for key in "${!Cp[@]}"; do
			printf "%s=%s" "$key" "${Cp[$key]}" >> $conflictsLogPootle
			printf "%s=%s" "$key" "${Cl[$key]}" >> $conflictsLogLiferay
		done;
		check_command
	fi
	log
	set +f
	unset R
	unset Cp
	unset Cl
	logt 3 "Moving processed file to source dir"
	logt 4 -n "Moving to $srcfile"
	mv $workingfile $srcfile
	check_command
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
	langFile="$HOME_DIR/conf/ext/$project/$language"
	if [ -e $langFile ]; then
		prefix=$(get_ext_language_prefix $project $locale)
		read_locale_file $langFile $prefix
	else
		logt 4 "$langFile not found: I won't override $locale translations"
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
	sources="${AP_PROJECT_SRC_LANG_BASE["$project"]}"
	langFile="$sources/$language"
	prefix=$(get_previous_language_prefix $project $locale)
	read_locale_file $langFile $prefix
}

function get_previous_language_prefix() {
	echo "p$1$2"
}
