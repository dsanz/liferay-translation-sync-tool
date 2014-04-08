#!/bin/bash

# T contains all translations
declare -gA T;
# K contains all keys in the template file
declare -ga K;

# regexp for separating key/value pairs (don't look for an /n at the end). Only works when value is not empty
declare -g kv_rexp="^([^=]+)=(.+)"

# regexp with matches the key in a key/value pair text line. Works even if value is empty
declare -g k_rexp="^([^=]+)="

# regexp with matches the value in a key/value pair text line. Works even if value is empty
declare -g v_rexp="^[^=]+=(.*)"

# regexp for locating translation files (does not include Language.properties)
declare -g trans_file_rexp="Language_[^\.]+\.properties"

# regexp for locating language files (includes Language.properties)
declare -g lang_file_rexp="Language[^\.]*\.properties"


#### Base functions

# returns a key which can be used to access the associative array T
# $1 is the key prefix
# $2 is the language key we want to access
function getTKey() {
	printf "%s" "$1$2"
}

# returns a value obtained from accessing the array T using the given key
# $1 is the key prefix
# $2 is the language key we want to access
function getTVal() {
	k="$1$2"
	printf "%s" "${T[$k]}"
}

# sets the specified value into array T under given key
# $1 is the key prefix
# $2 is the language key we want to access
# $3 is the value
function setTVal() {
	k="$1$2"
	T[$k]="$3"
}

# removes from T all entries for a given prefix
# $1 is the prefix
function clear_keys() {
	for key in "${K[@]}"; do
		k="$1$key"
		unset T['$k']
	done;
}
# returns true if line is a translation line (as opposed to comments or blank lines), false otherwise
# $1 is the line
function is_key_line() {
	[[ "$1" == *=* ]]
}
# returns true if key exists in array T, false otherwise
# $1 is the key prefix
# $2 is the key name
function exists_key() {
	k="$1$2"
	[ ${T[$k]+abc} ]
}
# returns true if value of a given key has changed amongst 2 key prefixes, false otherwise
# $1 is one key prefix
# $2 is the other key prefix
# $3 is the key name
function value_changed() {
	value_a=${T["$1$3"]}
	value_b=${T["$2$3"]}
	[[ "$value_a" != "$value_b" ]]
}

function is_translated_value() {
	rexp='\(Automatic [^\)]+\)$'
	! [[ "$1" =~ $rexp || "$1" == "" ]]
}

function is_translated() {
	is_translated_value "$(getTVal $1 $2)"
}
function is_automatic_copy() {
	rexp='\(Automatic Copy\)$'
	value=${T["$1$2"]}
	[[ "$value" =~ $rexp ]]
}
function is_automatic_translation() {
	rexp='\(Automatic Translation\)$'
	value=${T["$1$2"]}
	[[ "$value" =~ $rexp ]]
}

function get_locale_from_file_name() {
	file=$1
	if [[ $file == "$FILE.$PROP_EXT" ]]; then
		echo "template"
	else
		echo $file | sed -r 's/Language_([^\.]+)\.properties/\1/'
	fi
}

# reads a file and inserts keys in T (also in K if applicable)
# $1 is the file name path
# $2 is the key prefix where keys will be stored
# $3 is an optional boolean which states if keys are being read from the template or not
function read_locale_file() {
	lines=$(wc -l "$1" | cut -d' ' -f1)
	template=$3
	logt 4 -n "Reading file $1        "
	done=false;
	before=$(date +%s%N)
	if [[ $lines -gt 0 ]]; then
		until $done; do
			read line || done=true
			if is_key_line "$line" ; then
				# can't use [[ "$line" =~ $kv_rexp ]] because when reading a dumped store we can have empty keys
				[[ "$line" =~ $k_rexp ]] && key="${BASH_REMATCH[1]}"
				[[ "$line" =~ $v_rexp ]] && value="${BASH_REMATCH[1]}"
				setTVal $2 "$key" "$value"
				if [[ $template ]]; then
					K[${#K[@]}]=$key
				fi;
			else
				: #echo -n "."
			fi
		done < $1
	fi
	after=$(date +%s%N)
	loglc 0 $GREEN "[$lines lines read in $(echo "scale=3;($after - $before)/(1*10^09)" | bc) s.] "
}

function restore_file_ownership() {
	logt 3 "Restoring PO/ file ownership"
	logt -n 4 "chown ${FS_UID}:${FS_GID} -R $PODIR"
	chown ${FS_UID}:${FS_GID} -R $PODIR
	check_command
}