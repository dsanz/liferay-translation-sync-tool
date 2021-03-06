#!/bin/bash

declare -g backported_postfix=".backported"

declare -Ag charc # colors
declare -Ag chart # text legend

# L contains all locales in target_dir
declare -ag L;

# useful paths for backporting
declare -g source_english_path;    # location of Language.properties in source branch
declare -g target_english_path;    # location of Language.properties in target branch
declare -g source_lang_path;       # location of Language_*.properties in source branch
declare -g target_lang_path;       # location of Language_*.properties in target branch
declare -g source_dir
declare -g target_dir
declare -g lang_file;

charc["x"]=$BLUE; chart["x"]="No action, key doesn't exist in source branch"
charc["t"]=$LILA; chart["t"]="No action, key is automatic translated in target branch and untranslated in source branch"
charc["c"]=$COLOROFF; chart["c"]="No action, key is automatic copied both in source and target branches"
charc["b"]=$YELLOW; chart["b"]="Backport!, key is automatic copied in target branch and automatic translated in source branch."
charc["B"]=$WHITE; chart["B"]="Backport!, key untranslated in target and translated in source, same english meaning"
charc["r"]=$CYAN; chart["r"]="No action, key translated in source, but different english meaning. Human review required (semantic change)"
charc["R"]=$GREEN; chart["R"]="No action, key translated both in source and target, translations are different but same english meaning. Human review required (refinement)"
charc["·"]=$LILA; chart["·"]="No action, key translated both in source and target, same english meaning and translation"
charc["!"]=$RED; chart["!"]="No action, uncovered case"
charc["#"]=$COLOROFF; chart["#"]="No action, line is a comment"

function backport() {
	now="$(date +%s%N)"
	project="$1"
	locale="$2"
	logt 2 "Backporting $project ($locale)"
	clear_translations
	read_lang_files $locale
	file="${target_lang_path}${backported_postfix}"
	file_hrr_improvements="${target_lang_path}.review.improvements"
	file_hrr_changes="${target_lang_path}.review.changes"
	declare -A result
	backports=0
	improvements=0
	changes=0
	deprecations=0
	logt 3 "Writing into $file "
	rm -f $file $file_hrr_improvements $file_hrr_changes
	done=false;
	format="%s\n";
	until $done; do
		if ! read line; then
			format="%s"			done=true;

		fi;
		result[$file]="$line"
		result[$file_hrr_improvements]="$line"
		result[$file_hrr_changes]="$line"
		char="!"
		if is_key_line "$line" ; then
			[[ "$line" =~ $kv_rexp ]] && key="${BASH_REMATCH[1]}"	# Let process the key....
			if exists_in_new $key; then							# key exists in newer version
				if is_translated $new_lang $key; then			#	key is translated in the newer version :)
					if is_translated $old_lang $key; then		#		key is also translated in the old version
						if english_value_changed $key; then		#			english original changed amongst versions 	> there is a semantic change, human review required
							result[$file_hrr_changes]="${key}=${T[$new_lang$key]}"
							char="r"
							(( changes++ ))
						else									#			english unchanged amongst versions
							if lang_value_changed $key; then	#				translation changed amongst version		> there is a refinement, human review requirement
								result[$file_hrr_improvements]="${key}=${T[$new_lang$key]}"
								char="R"
								(( improvements++ ))
							else								#				translation unchanged amongst version		> none to do
								char="·"
							fi
						fi
					else										#		key is not translated in the old version		> lets try to backport it
						if english_value_changed $key; then		#			english original changed amongst versions 	> there is a semantic change, human review required
							result[$file_hrr_changes]="${key}=${T[$new_lang$key]}"
							char="r"
							(( changes++ ))
						else									#			english unchanged amongst versions 			> backport it!
							result[$file]="${key}=${T[$new_lang$key]}"
							char="B"
							(( backports++ ))
						fi
					fi
				else											#	key is untranslated in the newer version			> almost none to do :(
					if is_automatic_copy $old_lang $key; then	#		old translation is a mere copy
						if is_automatic_translation $new_lang $key; then #	new translation is automatic				> lets backport
							result[$file]="${key}=${T[$new_lang$key]}"
							char="b"
							(( backports++ ))
						else
							char="c"							#			both newer and older translations are automatic copies
						fi
					else
						char="t"								#		untranslated in newer, automatic translated in older
					fi
				fi
			else												# key doesn't exist in newer version
				char="x"
				(( deprecations++ ))
			fi
		else
			char="#"
		fi

		printf "$format" "${result[$file]}" >> $file
		printf "$format" "${result[$file_hrr_improvements]}" >> $file_hrr_improvements
		printf "$format" "${result[$file_hrr_changes]}" >> $file_hrr_changes
		loglc 0 "${charc[$char]}" -n "$char"
	done < $target_lang_path
	log

	logt 3 "Moving $file to $target_lang_path"
	mv $file $target_lang_path
	file=$target_lang_path
	logt 3 "Summary of $project ($locale) backport process:"
	logt 4 "- $backports keys backported"
	logt 4 "- $deprecations keys are in $target_english_path but not in $source_english_path"
	if [[ $improvements -eq 0 ]]; then
		rm  -f $file_hrr_improvements;
		logt 4 "- No improvements over previous translations in $target_lang_path"
	else
		logt 4 "- $improvements improvements over previous translations. Please review $file_hrr_improvements. You can diff it with $file"
	fi
	if [[ $changes -eq 0 ]]; then
		rm  -f $file_hrr_changes;
		logt 4 "- No semantic changes in $target_lang_path"
	else
		logt 4 "- $changes semantic changes. Please review $file_hrr_changes. You can diff it with $file"
	fi
	now="$(($(date +%s%N)-now))"
	seconds="$((now/1000000000))"
	milliseconds="$((now/1000000))"
	printf -v stats "Backport took %02d.%03d seconds" "$((seconds))" "${milliseconds}"
	logt 4 "- $stats"
	unset result;
}

function echo_legend() {
	logt 3 "Legend:"
	for char in ${!charc[@]}; do
		loglc 8 ${charc[$char]} "'$char' ${chart[$char]}.  "
	done;
}

# as opposed to the entry-point, standalone function, a batch backport function does not cover all the functionality
# because it'll be invoked from another function that controls the process and is in charge of setting work dirs as
# well as committing results and changing branches
function backport_project() {
	project="$1"
	if [ ! -d $2 ]; then
		logt 3 "Unable to backport, source dir '$2' does not exist"
	elif [ ! -d $3 ]; then
		logt 3 "Unable to backport, destination dir '$3' does not exist"
	else
		prepare_dirs $2 $3
		read_english_files
		if src_and_target_have_common_keys; then
			echo_legend
			for locale in "${L[@]}"; do
				backport "$project" "$locale"
			done
			logt 3 "Garbage collection (project)"
			unset L;
			declare -ag L;
		else
			logt 3 "No need to backport to $project as source and destination templates don't share keys"
		fi
	fi;
}

function read_english_files() {
	logt 3 "Reading english files"
	source_english_path="$source_dir/${FILE}.${PROP_EXT}"
	target_english_path="$target_dir/${FILE}.${PROP_EXT}"
	read_locale_file $source_english_path $new_english
	read_locale_file $target_english_path $old_english true
}

function read_lang_files() {
	logt 3 "Reading translation files"
	lang_file="${FILE}${LANG_SEP}$1.${PROP_EXT}";
	source_lang_path="$source_dir/$lang_file"
	target_lang_path="$target_dir/$lang_file"
	read_locale_file $source_lang_path $new_lang
	read_locale_file $target_lang_path $old_lang
}

function prepare_dirs() {
	logt 3 "Preparing working dirs"
	source_dir=$1
	target_dir=$2
	logt 4 "Source dir: $source_dir"
	logt 4 "Target dir: $target_dir"

	cd $target_dir
	logt 4 -n "Computing locales for $target_dir"
	for language_file in $(ls ${FILE}${LANG_SEP}*.$PROP_EXT); do
		L[${#L[@]}]=$(get_locale_from_file_name $language_file)
	done
	check_command
	locales="${L[@]}"
	logt 4 "Locales in target dir: $locales"
}

function get_ee_target_dir() {
	source_dir=$1
	if [[ $(echo $source_dir | grep "$SRC_PORTAL_BASE") != "" ]]; then
		sedExpr="s:$SRC_PORTAL_BASE:$SRC_PORTAL_EE_BASE:"
	else
		sedExpr="s:$SRC_PLUGINS_BASE:$SRC_PLUGINS_EE_BASE:"
	fi
	echo "$source_dir" | sed "$sedExpr"
}