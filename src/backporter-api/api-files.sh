#!/bin/bash

# L contains all locales in target_dir
declare -a L;

# useful paths for backporting
declare source_english_path;    # location of Language.properties in source branch
declare target_english_path;    # location of Language.properties in target branch
declare source_lang_path;       # location of Language_*.properties in source branch
declare target_lang_path;       # location of Language_*.properties in target branch


function compute_locales() {
	for language_file in $(ls $target_dir/${FILE}${LANG_SEP}*.$PROP_EXT); do
		locale=$(echo $language_file | sed -r "s:$target_dir\/${FILE}${LANG_SEP}([^\.]+).$PROP_EXT:\1:")
		L[${#L[@]}]=$locale
	done
	locales="${L[@]}"
	echo "  - Locales in target dir: '$locales'"
}

function read_english_files() {
	echo
	echo "Reading english files"
	set_english_paths
	read_locale_file $source_english_path $new_english
	read_locale_file $target_english_path $old_english true
}

function read_lang_files() {
	set_lang_paths $1
	read_locale_file $source_lang_path $new_lang
	read_locale_file $target_lang_path $old_lang
}

function set_base_paths() {
	source_dir=$1
	target_dir=$2
	if ! [[ ($source_dir == *$translations_dir*) || -f $source_dir/$english_file ]]; then
		source_dir=$source_dir$translations_dir
	fi;
	if ! [[ $target_dir == *$translations_dir* || -f $target_dir/$english_file ]]; then
		target_dir=$target_dir$translations_dir
	fi;
	echo "  - Source dir set to $source_dir"
	echo "  - Target dir set to $target_dir"
}

# sets source and target paths for Language.properties files
function set_english_paths() {
	source_english_path=$source_dir/$english_file
	target_english_path=$target_dir/$english_file
}

# sets source and target paths for Language_$1.properties files
function set_lang_paths() {
	lang_file="${FILE}${LANG_SEP}$1.${PROP_EXT}";
	source_lang_path=$source_dir/$lang_file
	target_lang_path=$target_dir/$lang_file
}

function prepare_dirs() {
	echo
	echo "Preparing working dirs"
	set_base_paths $1 $2
	if [[ $use_git == 0 ]]; then
		echo "  - Using git"
		check_git;
	else
		echo "  - Not using git"
	fi
	compute_locales
}

