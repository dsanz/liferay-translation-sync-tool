#!/bin/bash

declare -g backported_postfix=".backported"

declare -Ag charc # colors
declare -Ag chart # text legend

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

	if [[ $do_commit -eq 0 ]]; then
		logt 3 "Moving $file to $target_lang_path"
		mv $file $target_lang_path
		file=$target_lang_path
	fi
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

function clear_translations() {
	logt 3 -n "Garbage collection... "
	clear_keys $new_lang
	clear_keys $old_lang
	check_command
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
		echo_legend
		for locale in "${L[@]}"; do
			backport "$project" "$locale"
		done
		logt 3 "Garbage collection (project)"
		unset L;
		declare -ag L;
	fi;
}

