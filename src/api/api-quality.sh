#!/bin/sh

function run_quality_checks() {
    logt 1 "Running quality checks"

	for (( i=0; i<${#PROJECT_NAMES[@]}; i++ ));
	do
		project=${PROJECT_NAMES[$i]}
		languages=`ls $PODIR/$project`
        logt 2 "$project"
        logt 3 "Setting up per-project log file"
        check_dir "$logbase/$project/"

        logt 3 "Reading template file"
        read_pootle_exported_template $project
		for language in $languages; do
		    locale=$(get_locale_from_file_name $language)
		    if [[ "$locale" != "en" && "$language" =~ $trans_file_rexp ]]; then
                logt 2 "$project: $locale"
                logt 3 "Reading $language file"
                read_pootle_exported_language_file $project $language
                check_qa "$project" "$language"
                logt 3 -n "Garbage collection... "
                clear_keys "$(get_exported_language_prefix $project $locale)"
                check_command
            fi
		done
		logt 3 -n "Garbage collection (whole project)... "
		unset K
		unset T
		declare -gA T;
        declare -ga K;
		check_command
	done
}

function check_qa() {
    project="$1"
    language="$2"

    check_same_translation "$project" "$language"
    # more to come..
}

function check_same_translation() {
    project="$1"
    language="$2"

    logt 3 "Checking for same translations"
    exportedPrefix=$(get_exported_language_prefix $project $locale)
    numberOfKeys=${#K[@]}
    logt 4 "Keyset has $numberOfKeys keys "
    perProjectLogfile="$logbase/$project/same_translations_$locale.log"
    logt 4 "Please see $perProjectLogfile"
    for (( i=0; i<${numberOfKeys}; i++ )); do
        key_i=${K[$i]}
        translation_i=${T["$exportedPrefix$key_i"]}
        (( r=${i}+1 ))
        log -n "·"
        for (( j=${r}; j<${numberOfKeys}; j++ )); do
            key_j=${K[$j]}
            if [[ "$translation_i" == "${T["$exportedPrefix$key_j"]}" ]]; then
                log -n "*"
                echo "[$key_i, $key_j]=$translation_i" >> $perProjectLogfile
            fi
        done
    done;
}