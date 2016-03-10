# given a project and a language, reads the Language_xx.properties file
# exported from pootle and puts it into array T using the locale as prefix
function read_ext_language_file() {
	project="$1";
	language="$2";
	logt 3 "Reading $project $language overriding translations"
	locale=$(get_locale_from_file_name $language)
	langFile="$HOME_DIR/conf/ext/$project/$language"
	if [ -e $langFile ]; then
		prefix=$(get_ext_language_prefix $project $locale)
		read_locale_file $langFile $prefix
	else
		logt 4 "$langFile not found: I won't override $locale translations"
	fi
}

function get_ext_language_prefix() {
	echo "x$1$2"
}

# given a project, reads the Language.properties file exported from pootle
# and puts it into array T using the project as prefix
function read_pootle_exported_template() {
	project="$1";
	logt 3 "Reading $project template file"
	template="$PODIR/$project/$FILE.$PROP_EXT"
	prefix=$(get_template_prefix $project $locale)
	check_dir "$PODIR/$project/"
	export_project_template $project
	read_locale_file $template $prefix true
}

function get_template_prefix() {
	echo $1
}

# given a project and a language, reads the Language_xx.properties file
# exported from pootle and puts it into array T using the locale as prefix
function read_pootle_exported_language_file() {
	project="$1";
	language="$2";
	logt 3 "Reading $project $language file as exported by Pootle"
	locale=$(get_locale_from_file_name $language)
	langFile="$TMP_PROP_OUT_DIR/$project/$language"
	prefix=$(get_exported_language_prefix $project $locale)
	read_locale_file $langFile $prefix
}

function get_exported_language_prefix() {
	echo $1$2
}

function read_source_code_language_file() {
	project="$1";
	language="$2";
	logt 3 "Reading $project $language file from source code branch (just pulled)"
	locale=$(get_locale_from_file_name $language)
	sources="${AP_PROJECT_SRC_LANG_BASE["$project"]}"
	langFile="$sources/$language"
	prefix=$(get_source_code_language_prefix $project $locale)
	read_locale_file $langFile $prefix
}

function get_source_code_language_prefix() {
	echo "p$1$2"
}

function read_pootle_store() {
	project="$1";
	language="$2";
	logt 3 "Reading $project $language pootle store"
	locale=$(get_locale_from_file_name $language)
	langFile="$TMP_PROP_OUT_DIR/$project/$language.store"
	check_dir "$TMP_PROP_OUT_DIR/$project/"
	dump_store "$project" "$locale" "$langFile"
	prefix=$(get_store_language_prefix $project $locale)
	read_locale_file $langFile $prefix $3
}

function get_store_language_prefix() {
	echo "s$1$2"
}