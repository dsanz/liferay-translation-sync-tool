#!/bin/bash

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