#!/bin/bash

# pootle2src implements the sync between pootle and liferay source code repos
# - tells pootle to update its files with the DB contents
# - copy and convert those files to utf-8
# - pulls from upstream the master branch
# - process translations by comparing pootle export with contents in master, using a set of predefined rules
# - makes a first commit of this
# - runs ant build-lang for every project
# - commits and pushes the result
# - creates a Pull Request for each involved git root, sent to a different reviewer.
# all the process is logged
function pootle2src() {
	loglc 1 $RED "Begin Sync[Pootle -> Liferay source code]"
	display_source_projects_action
	clean_temp_output_dirs
	export_pootle_translations_to_temp_dirs
	restore_file_ownership
	process_translations_repo_based
	do_commit false false "Translations sync from translate.liferay.com"
	build_lang
	do_commit true true "build-lang"
	loglc 1 $RED "End Sync[Pootle -> Liferay source code]"
}

#
# new, repository-based sync logic
#

function process_translations_repo_based() {
	logt 1 "Processing translations for export"

	# TODO: print whatever legend we have

	for git_root in "${!GIT_ROOTS[@]}"; do
		process_project_translations_repo_based $git_root true
	done;
}

# process translations from a repo-based
function process_project_translations_repo_based() {
	git_root="$1"

	source_project="${GIT_ROOT_POOTLE_PROJECT_NAME[$git_root]}"
	target_project_list="$(echo ${AP_PROJECTS_BY_GIT_ROOT["$git_root"]} | sed 's: :\n:g' | sort)"
	languages=`ls $PODIR/$source_project`

	logt 2 "$source_project"
	logt 3 "Setting up per-project log file"
	check_dir "$logbase/$source_project/"

	# this has to be read once per source project
	read_pootle_exported_template $source_project

	for language in $languages; do
		locale=$(get_locale_from_file_name $language)
		if [[ "$locale" != "en" && "$language" =~ $trans_file_rexp ]]; then
			logt 2 "$source_project: $locale"

			# these have to be read once per source project and language
			read_pootle_exported_language_file $source_project $language
			read_pootle_store $source_project $language
			read_ext_language_file $source_project $language

			# iterate all projects in the destination project list and 'backport' to them
			while read target_project; do
				if [[ $target_project != $source_project ]]; then
					# this has to be read once per target project and locale
					read_source_code_language_file $target_project $language

					refill_translations_repo_based $source_project $target_project $language $publish_translations

					logt 3 -n "Garbage collection (target: $target_project, $locale)... "
					clear_keys "$(get_source_code_language_prefix $target_project $locale)"
					check_command
				fi
			done <<< "$target_project_list"

			logt 3 -n "Garbage collection (source: $source_project, $locale)... "
			clear_keys "$(get_exported_language_prefix $source_project $locale)"
			clear_keys "$(get_store_language_prefix $source_project $locale)"
			clear_keys "$(get_ext_language_prefix $source_project $locale)"
		fi
	done

	logt 3 -n "Garbage collection (source project: $source_project)... "
	unset K
	unset T
	declare -gA T;
	declare -ga K;
	check_command
}


function refill_translations_repo_based() {
	set -f
	source_project="$1";
	target_project="$2";
	language="$3";
	publish_translations="$4"

	locale=$(get_locale_from_file_name $language)

	# involved file paths
	target_file="${AP_PROJECT_SRC_LANG_BASE["$target_project"]}/$language"
	workingfile="${target_file}.final"
	copyingLogfile="$logbase/$project/$language"
	conflictsLogPootle="$logbase/$project/$language.conflicts.pootle"
	conflictsLogLiferay="$logbase/$project/$language.conflicts.liferay"

	[[ -f $workingfile ]] && rm $workingfile # when debugging we don't run all sync stages so we can have this file from a previous run

	# source project prefixes for array accessing
	templatePrefix=$(get_template_prefix $source_project $locale)
	exportedPrefix=$(get_exported_language_prefix $source_project $locale)
	storePrefix=$(get_store_language_prefix $source_project $locale)
	extPrefix=$(get_ext_language_prefix $source_project $locale)

	# target project prefixes for array accessing
	sourceCodePrefix=$(get_source_code_language_prefix $target_project $locale)

	declare -A R  # reverse translations
	declare -A Cp  # conflicts - pootle value
	declare -A Cl  # conflicts - liferay source value

	logt 3 "Exporting translations from $source_project to $target_project"
	logt 0
	done=false;
	format="%s\n";
	OLDIFS=$IFS
	IFS=
	# read the target language file. Variables meaning:
	# Tkey: target file language key
	# Tval: target file language value. This one will be written to the exported file associated to Tkey
	# SvalTpl: source file language value to Tkey

	until $done; do
		if ! read -r line; then
			done=true;
			format="%s"
		fi;
		if [ ! "$line" == "" ]; then
			char="!"
			if is_key_line "$line" ; then
				[[ "$line" =~ $kv_rexp ]] && Tkey="${BASH_REMATCH[1]}" && Tval="${BASH_REMATCH[2]}"
				SvalTpl=${T["$templatePrefix$Tkey"]}
				valueExp=${T["$exportedPrefix$Tkey"]}                            # get translation exported by pootle

				if exists_ext_value $extPrefix $Tkey; then                       # has translation to be overriden?
					Tval=${T["$extPrefix$Tkey"]}
					char="o"
				elif [[ "$valueExp" == "$SvalTpl" ]]; then                     # ok, no overriding. Now, is exported value = template value?
					valueStore=${T["$storePrefix$Tkey"]}                         #   then let's see if translators wrote the template value by hand in the text box
					if [[ "$valueStore" == "$SvalTpl" ]]; then                 #   was it translated that way on purpose?
						char="e"                                                #       use the template value. English is ok in this case.
						Tval=$SvalTpl
					else                                                        #   otherwise, key is really untranslated in pootle
						valuePrev=${T["$sourceCodePrefix$Tkey"]}                   #       let's look for the current key translation in master
						if is_translated_value "$valuePrev"; then               #       is the key translated in master? [shouldn't happen unless we run -r before a -p]
							if [[ "$valuePrev" != "$SvalTpl" ]]; then          #           ok, key is already translated in master. is that value different from the template?
								char="r"                                        #               ok, then master is translated but Pootle not, hmmm! we have a reverse-path
								Tval="$valuePrev"                               #               let's keep`the value in master as a good default.
								R[$Tkey]="$Tval";                               #               and memorize it so that Pootle can be properly updated later
							else                                                #           ok, value in master is just like the template
								char="a"                                        #               discard it! ant build-lang will do
								Tval=""
							fi
						else                                                    #       value in master is not translated. This means an auto-copy or auto-translation
							char="u"                                            #           let's reuse it, we are saving build-lang work. don't do same work twice
							Tval=$valuePrev
						fi;
					fi
				else                                                            # ok, no overriding, and value is not the english one: it's supposed to be a valid translation!!
					Tval=${T["$exportedPrefix$Tkey"]}                           #   get translation exported by pootle
					valuePrev=${T["$sourceCodePrefix$Tkey"]}                       #   get the translation from master
					if is_translated_value "$valuePrev"; then                   #   is the master value translated?
						if [[ "$valuePrev" != "$Tval" ]]; then                 #      is this translation different than the one pootle exported?
							char="x"                                            #           ok, we have a conflict, pootle wins. Let user know
							Cp[$Tkey]="$Tval"                                   #           take note for logging purposes
							Cl[$Tkey]="$valuePrev"
						else                                                    #      ok, translation in master is just like the exported by pootle.
							char="·"                                            #           no-op, already translated both in pootle and master
						fi
					else                                                        #   master value is NOT translated but auto-translated/auto-copied
						char="p"                                                #      ok, translated in pootle, but not in master. OK!!
					fi
				fi
				result="${Tkey}=${Tval}"
			else                                                               # is it a comment line?
				char="#"
				result="$line"                                                 #    get the whole line
			fi
			printf "$format" "$result" >> $workingfile
			printf "$format"  "[${char}]___${Tkey}" >> $copyingLogfile
			loglc 0 "${charc[$char]}" -n "$char"
		fi;
	done < $target_file
	IFS=$OLDIFS

	logt 0
	if [[ "$publish_translations" == true ]]; then
		if [[ ${#R[@]} -gt 0 ]];  then
			# required by api-db to access pootle DB in case we need to know if a term was translated using the english word or not
			storeId=$(get_store_id $source_project $locale)
			local path=$(get_pootle_path $source_project $locale)

			logt 3 "Submitting translations from source to pootle. Next time be sure to run this manager with -p option!"
			start_pootle_session
			for key in "${!R[@]}"; do
				value="${R[$Tkey]}"
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
	logt 4 -n "Moving to $target_file"
	mv $workingfile $target_file
	check_command
}
