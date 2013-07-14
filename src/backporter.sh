#!/bin/bash

# Author:		Daniel Sanz

. api/api-git.sh
. api/api-properties.sh
. backporter-api/api-properties.sh
. backporter-api/api-git.sh
. backporter-api/api-files.sh

declare translations_dir="/portal-impl/src/content"
declare backported_postfix=".backported"

declare english_file="${FILE}.${PROP_EXT}";
declare source_dir
declare target_dir
declare lang_file;

declare version="0.7"
declare product="Liferay translation backporter v$version"

#### Top level functions


function backport() {
	now="$(date +%s%N)"
	echo
	echo "Backporting to '$1'"
	clear_translations
	read_lang_files $1
	file="${target_lang_path}${backported_postfix}"
	file_hrr_improvements="${target_lang_path}.review.improvements"
	file_hrr_changes="${target_lang_path}.review.changes"
	declare -A result
	backports=0
	improvements=0
	changes=0
	deprecations=0
	echo "  Writing into $file "

	rm -f $file $file_hrr_improvements $file_hrr_changes
	done=false;
	until $done; do
	    read line || done=true
		result[$file]="$line"
		result[$file_hrr_improvements]="$line"
		result[$file_hrr_changes]="$line"
		char="x"
		if is_key_line "$line" ; then
			[[ "$line" =~ $kv_rexp ]] && key="${BASH_REMATCH[1]}"	# Let process the key....
			if exists_in_new $key; then							# key exists in newer version
				if is_translated $new_lang $key; then			#	key is translated in the newer version :)
					if is_translated $old_lang $key; then		#		key is also translated in the old version
						if english_value_changed $key; then		#			english original changed amongst versions 	> there is a semantic change, human review required
							result[$file_hrr_changes]="${key}=${T[$new_lang,$key]}"
							char="r"
							(( changes++ ))
						else									#			english unchanged amongst versions
							if lang_value_changed $key; then	#				translation changed amongst version		> there is a refinement, human review requirement
								result[$file_hrr_improvements]="${key}=${T[$new_lang,$key]}"
								char="R"
								(( improvements++ ))
							else								#				translation unchanged amongst version		> none to do
								char="."
							fi
						fi
					else										#		key is not translated in the old version		> lets try to backport it
						if english_value_changed $key; then		#			english original changed amongst versions 	> there is a semantic change, human review required
							result[$file_hrr_changes]="${key}=${T[$new_lang,$key]}"
							char="r"
							(( changes++ ))
						else									#			english unchanged amongst versions 			> backport it!
							result[$file]="${key}=${T[$new_lang,$key]}"
							char="B"
							(( backports++ ))
						fi
					fi
				else											#	key is untranslated in the newer version			> almost none to do :(
					if is_automatic_copy $old_lang $key; then	#		old translation is a mere copy
						if is_automatic_translation $new_lang $key; then #	new translation is automatic				> lets backport
							result[$file]="${key}=${T[$new_lang,$key]}"
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
				char="X"
				(( deprecations++ ))
			fi
		else
			char="#"
		fi
		echo ${result[$file]} >> $file
		echo ${result[$file_hrr_improvements]} >> $file_hrr_improvements
		echo ${result[$file_hrr_changes]} >> $file_hrr_changes
		echo -n $char
	done < $target_lang_path
	echo;
	if [[ $do_commit -eq 0 ]]; then
		echo  "  Moving $file to $target_lang_path"
		mv $file $target_lang_path
		file=$target_lang_path
	fi
	echo "  Summary of '$1' backport process:"
	echo "   - $backports keys backported"
	echo "   - $deprecations keys are in $target_english_path but not in $source_english_path"
	if [[ $improvements -eq 0 ]]; then
		rm  -f $file_hrr_improvements;
		echo "   - No improvements over previous translations in $target_lang_path"
	else
		echo "   - $improvements improvements over previous translations. Please review $file_hrr_improvements. You can diff it with $file"
	fi
	if [[ $changes -eq 0 ]]; then
		rm  -f $file_hrr_changes;
		echo "   - No semantic changes in $target_lang_path"
	else
		echo "   - $changes semantic changes. Please review $file_hrr_changes. You can diff it with $file"
	fi
	now="$(($(date +%s%N)-now))"
	seconds="$((now/1000000000))"
	milliseconds="$((now/1000000))"
	printf "   - Backport took %02d.%03d seconds\n" "$((seconds))" "${milliseconds}"
}

function clear_translations() {
    clear_keys $new_lang
    clear_keys $old_lang
}

function echo_legend() {
	echo
	echo "Backport Legend:"
	echo "   #: No action, line is a comment"
	echo "   X: No action, key doesn't exist in newer version"
	echo "   t: No action, key is automatic translated in older version and untranslated in newer one"
	echo "   c: No action, key is automatic copied both in older and newer versions"
	echo "   b: Backport!, key is automatic copied in older and automatic translated in newer one."
	echo "   B: Backport!, key untranslated in older and translated in newer one, same english meaning."
	echo "   r: No action, key translated in newer, but different english meaning. Human review required (semantic change, echoed to $file_hrr_changes)"
	echo "   R: No action, key translated in newer and older, translations are different but same english meaning. Human review required (refinement, echoed to $file_hrr_improvements)"
	echo "   .: No action, key translated in newer and older, same english meaning and translation"
	echo "   x: No action, uncovered case"
}



function usage() {
	echo "Usage: $0 <source-dir> <target-dir> [-ng]"
	echo "   <source-dir> and <target-dir> must either:"
	echo "      - Contain language files (Language.properties et al), or"
	echo "      - Point to the source root (backporter will add 'src/portal-impl/content' to the paths)"
	echo "   Translations will be backported from source to target. Only language files in target are backported"
	echo "   -ng disables git"
	exit 1
}

echo "$product"
test $# -eq 2 || test $# -eq 3 || usage;
[[ $3 == "-ng" ]] && use_git=1
prepare_dirs $1 $2
read_english_files
for locale in "${L[@]}"; do
	backport $locale
done
echo_legend
commit_result
echo
echo "Backport finished in $SECONDS s."

#### test functions

function test_old_keys() {
	for key in "${K[@]}"; do
		echo "$key:"

		echo -n " - is_translated: "
		if (is_translated $old_lang $key); then
			echo "yes"
		else
			echo "no"
		fi;
		echo -n " - is_automatic_copy: "
		if is_automatic_copy $old_lang $key; then
		echo "yes"
		else
			echo "no"
		fi;
		echo -n " - is_automatic_translation: "
		if is_automatic_translation $old_lang $key; then
			echo "yes"
		else
			echo "no"
		fi;
		echo -n " - english_value_changed: "
		if english_value_changed $key; then
			echo "yes"
		else
			echo "no"
		fi;
		echo -n " - lang_value_changed: "
		if lang_value_changed $key; then
			echo "yes"
		else
			echo "no"
		fi;
		echo -n " - exists_in_new: "
		if exists_in_new $key; then
			echo "yes"
		else
			echo "no"
		fi;
		echo -n " - exists_in_old: "
		if exists_in_old $key; then
			echo "yes"
		else
			echo "no"
		fi;
		echo;
	done;
}
