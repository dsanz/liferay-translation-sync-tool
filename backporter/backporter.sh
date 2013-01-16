#!/bin/bash

# T contains all translations
declare -A T;
# K contains all keys in the $target_english_path file
declare -a K;
# L contains all locales in target_dir
declare -a L;
# key prefix for new (source) english key names
declare new_english="N";
# key prefix for old (target) english key names
declare old_english="O";
# key prefix for new (source) language key names
declare new_lang="n";
# key prefix for old (target) language key names
declare old_lang="o";
# regexp for separating key/value pairs
declare kv_rexp="^([^=]+)=(.*)"

declare file_prefix="Language";
declare file_ext="properties";
declare file_sep="_";

declare english_file="${file_prefix}.${file_ext}";
declare source_dir
declare target_dir
declare lang_file;
declare source_english_path;
declare target_english_path;
declare source_lang_path;
declare target_lang_path;


#### Base functions

# returns true if line is a translation line (as opposed to comments or blank lines), false otherwise
# $1 is the line
function is_key_line() {
	[[ "$1" == *=* ]]
}
# returns true if key exists in array T, false otherwise
# $1 is the key prefix
# $2 is the key name
function exists_key() {
	[ ${T[$1,$2]+abc} ]
}
# returns true if value of a given key has changed amongst 2 key prefixes, false otherwise
# $1 is one key prefix
# $2 is the other key prefix
# $3 is the key name
function value_changed() {
	[[ ${T[$1,$3]} != ${T[$2,$3]} ]]
}
#### Core API functions

function english_value_changed() {
	value_changed $new_english $old_english $1
}
function lang_value_changed() {
	value_changed $new_lang $old_lang $1
}
function exists_in_new() {
	exists_key $new_english $1
}
function exists_in_old() {
	exists_key $old_english $1
}
function is_translated() {
	rexp='\(Automatic [^\)]+\)$'
	! [[ "${T[$1,$2]}" =~ $rexp ]]
}
function is_automatic_copy() {
	rexp='\(Automatic Copy\)$'
	[[ "${T[$1,$2]}" =~ $rexp ]]
}
function is_automatic_translation() {
	rexp='\(Automatic Translation\)$'
	[[ "${T[$1,$2]}" =~ $rexp ]]
}

#### Top level functions

# sets source and target paths for Language.properties files
function set_english_paths() {
	source_english_path=$source_dir/$english_file
	target_english_path=$target_dir/$english_file
}

# sets source and target paths for Language_$1.properties files
function set_lang_paths() {
	lang_file="${file_prefix}${file_sep}$1.${file_ext}";
	source_lang_path=$source_dir/$lang_file
	target_lang_path=$target_dir/$lang_file
}

# reads a file and inserts keys in T (also in K if applicable)
# $1 is the file name path
# $2 is the key prefix where keys will be stored
function read_locale_file() {
	lines=$(wc -l "$1" | cut -d' ' -f1)
	echo -n "  Reading file $1        "
	counter=0
	while read line; do
		printf "\b\b\b\b\b"
		printf "%5s" "$(( 100 * (counter+1) / lines ))%"
		(( counter++ ))
		if is_key_line "$line" ; then
			[[ "$line" =~ $kv_rexp ]] && key="${BASH_REMATCH[1]}" && value="${BASH_REMATCH[2]}"
			T[$2,$key]=$value
			if [[ $2 == $old_english ]]; then
				K[${#K[@]}]=$key
			fi;
		else
			: #echo -n "."
		fi
	done < $1
	echo;
}

function backport() {
	now="$(date +%s%N)"
	echo
	echo "Backporting to '$1'"
	clear_translations
	read_lang_files $1
	file="${target_lang_path}.backported"
	file_hrr_improvements="${target_lang_path}.review.improvements"
	file_hrr_changes="${target_lang_path}.review.changes"
	declare -A result
	backports=0
	improvements=0
	changes=0
	deprecations=0
	echo "  Writing into $file: "

	rm -f $file $file_hrr_improvements $file_hrr_changes
	while read line; do
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
		if [[ "$line" != "${result[$file_hrr_improvements]}" ]]; then
			echo ${result[$file_hrr_improvements]} >> $file_hrr_improvements
		fi
		if [[ "$line" != "${result[$file_hrr_changes]}" ]]; then
			echo ${result[$file_hrr_changes]} >> $file_hrr_changes
		fi
		echo -n $char
	done < $target_lang_path
	echo;
	echo "  Summary" # commented echoes will be displayed in verbose mode (future option)
	echo "  - $backports keys backported"
	echo "  - $deprecations deprecated keys which don't exist in $source_english_path"
	if [[ $improvements -eq 0 ]]; then
		rm  -f $file_hrr_improvements;
		#echo "  - No improvements over previous translations in $target_lang_path"
	else
		echo "  - $improvements improvements over previous translations. Please review $file_hrr_improvements. You can diff it with $target_lang_path"
	fi
	if [[ $changes -eq 0 ]]; then
		rm  -f $file_hrr_changes;
		#echo "  - No semantic changes in $target_lang_path"
	else
		echo "  - $changes semantic changes. Please review $file_hrr_changes. You can diff it with $target_lang_path"
	fi
	now="$(($(date +%s%N)-now))"
	seconds="$((now/1000000000))"
	milliseconds="$((now/1000000))"
	printf "  - Backport took %02d.%03d seconds\n" "$((seconds))" "${milliseconds}"

}

function clear_translations() {
	for key in "${K[@]}"; do
		unset 'T[$new_lang,$key]'
	 	unset 'T[$old_lang,$key]'
	done;
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

function read_english_files() {
	echo "Reading english files"
	set_english_paths
	read_locale_file $source_english_path $new_english
	read_locale_file $target_english_path $old_english
}

function read_lang_files() {
	set_lang_paths $1
	read_locale_file $source_lang_path $new_lang
	read_locale_file $target_lang_path $old_lang
}

function compute_locales() {
	for language_file in $(ls $target_dir/${file_prefix}${file_sep}*.$file_ext); do
		locale=$(echo $language_file | sed -r "s:$target_dir\/${file_prefix}${file_sep}([^\.]+).$file_ext:\1:")
		L[${#L[@]}]=$locale
	done
	locales="${L[@]}"
	echo "Backport process will be done for '$locales'"
}

function usage() {
	echo "Usage: $0 <source dir> <target dir>"
	echo "   <source dir> and <target dir> must contain language files (Language.properties et al)"
	echo "   Translations will be backported from source to target. Only language files in target are backported"
	exit 1
}

echo "Liferay language key backporter v0.5"
test $# -eq 2 || usage;
source_dir=$1
target_dir=$2
compute_locales
read_english_files
for locale in "${L[@]}"; do
	backport $locale
done
echo_legend
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
