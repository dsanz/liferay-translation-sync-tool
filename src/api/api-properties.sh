#!/bin/bash

# T contains all translations
declare -gA T;
# K contains all keys in the template file
declare -ga K;

# regexp for separating key/value pairs
declare -g kv_rexp="^([^=]+)=(.+)$"

#### Base functions

# returns a key which can be used to access the associative array T
# $1 is the key prefix
# $2 is the language key we want to access
function getTKey() {
    echo $1$2
}

# returns a value obtained from accessing the array T using the given key
# $1 is the key prefix
# $2 is the language key we want to access
function getTVal() {
    k=$(getTKey $1 $2)
    echo ${T[$k]}
}

# sets the specified value into array T under given key
# $1 is the key prefix
# $2 is the language key we want to access
# $3 is the value
function setTVal() {
    k=$(getTKey $1 $2)
    T[$k]="$3"
}

# removes from T all entries for a given prefix
# $1 is the prefix
function clear_keys() {
    for key in "${K[@]}"; do
        k="$(getTKey $1 $key)"
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
    k=$(getTKey $1 $2)
    [ ${T[$k]+abc} ]
}
# returns true if value of a given key has changed amongst 2 key prefixes, false otherwise
# $1 is one key prefix
# $2 is the other key prefix
# $3 is the key name
function value_changed() {
	[[ $(getTVal $1 $3) != $(getTVal $2 $3) ]]
}

function is_translated_value() {
	rexp='\(Automatic [^\)]+\)$'
	! [[ "$1" =~ $rexp ]]
}

function is_translated() {
	is_translated_value "$(getTVal $1 $2)"
}
function is_automatic_copy() {
	rexp='\(Automatic Copy\)$'
	[[ "$(getTVal $1 $2)" =~ $rexp ]]
}
function is_automatic_translation() {
	rexp='\(Automatic Translation\)$'
	[[ "$(getTVal $1 $2)" =~ $rexp ]]
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
	echo -n "  Reading file $1        "
	counter=0
	while read line; do
		printf "\b\b\b\b\b"
		printf "%5s" "$(( 100 * (counter+1) / lines ))%"
		(( counter++ ))
		if is_key_line "$line" ; then
			[[ "$line" =~ $kv_rexp ]] && key="${BASH_REMATCH[1]}" && value="${BASH_REMATCH[2]}"
			setTVal $2 "$key" "$value"
			if [[ $template ]]; then
				K[${#K[@]}]=$key
			fi;
		else
			: #echo -n "."
		fi
	done < $1
	echo;
}
