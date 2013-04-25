#!/bin/bash

# T contains all translations
declare -A T;
# K contains all keys in the template file
declare -a K;

# regexp for separating key/value pairs
declare kv_rexp="^([^=]+)=(.*)"

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
