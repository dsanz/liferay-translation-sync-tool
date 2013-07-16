#!/bin/bash

# Author:		Daniel Sanz

. api/api-git.sh
. api/api-properties.sh
. api/api-version.sh
. backporter-api/api-properties.sh
. backporter-api/api-git.sh
. backporter-api/api-files.sh
. backporter-api/api-backporter.sh

function usage() {
	echo "Usage: $0 <source-dir> <target-dir> [-ng]"
	echo "   <source-dir> and <target-dir> must either:"
	echo "      - Contain language files (Language.properties et al), or"
	echo "      - Point to the source root (backporter will add 'src/portal-impl/content' to the paths)"
	echo "   Translations will be backported from source to target. Only language files in target are backported"
	echo "   -ng disables git"
	exit 1
}

function main() {
    echo "$product"
    test $# -eq 2 || test $# -eq 3 || usage;
    [[ $3 == "-ng" ]] && use_git=1
    prepare_dirs $1 $2
    check_git $1 $2
    read_english_files
    for locale in "${L[@]}"; do
    	backport $locale
    done
    echo_legend
    commit_result $2
    echo
    echo "Backport finished in $SECONDS s."
}

main $@

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
