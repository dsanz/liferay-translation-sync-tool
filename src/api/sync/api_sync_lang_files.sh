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
	local project="$1";
	logt 3 "Reading $project template file"
	local template="$PODIR/$project/$FILE.$PROP_EXT"
	check_dir "$PODIR/$project/"
	export_project_template $project
	local prefix=$(get_template_prefix $project)
	read_locale_file $template $prefix true
}

function get_template_prefix() {
	echo $1
}

function read_pootle_exported_template_before_update_from_templates() {
	local project="$1";
	logt 3 "Reading $project template file (before updating from templates)"
	local template="$PODIR/$project/$FILE.$PROP_EXT"
	check_dir "$PODIR/$project/"
	export_project_template $project
	local prefix=$(get_template_prefix_before_update_from_templates $project)
	# let's consider this another store, not a template one
	read_locale_file $template $prefix false
}

function get_template_prefix_before_update_from_templates() {
	echo "t$1"
}

# given a project and a language, reads the Language_xx.properties file
# exported from pootle and puts it into array T using the locale as prefix
function read_pootle_exported_language_file() {
	local project="$1";
	local language="$2";
	logt 3 "Reading $project $language file as exported by Pootle"
	local locale=$(get_locale_from_file_name $language)
	local langFile="$TMP_PROP_OUT_DIR/$project/$language"
	local prefix=$(get_exported_language_prefix $project $locale)
	read_locale_file $langFile $prefix
}

function get_exported_language_prefix() {
	echo $1$2
}

function read_source_code_language_file() {
	local project="$1";
	local language="$2";
	logt 3 "Reading $project $language file from source code branch (just pulled)"
	local locale=$(get_locale_from_file_name $language)
	local sources="${AP_PROJECT_SRC_LANG_BASE["$project"]}"
	local langFile="$sources/$language"
	local prefix=$(get_source_code_language_prefix $project $locale)
	read_locale_file $langFile $prefix
}

function get_source_code_language_prefix() {
	echo "p$1$2"
}

function read_pootle_store() {
	local project="$1";
	local language="$2";
	logt 3 "Reading $project $language pootle store"
	local locale=$(get_locale_from_file_name $language)
	local langFile="$TMP_PROP_OUT_DIR/$project/$language.store"
	check_dir "$TMP_PROP_OUT_DIR/$project/"
	dump_store "$project" "$locale" "$langFile"
	local prefix=$(get_store_language_prefix $project $locale)
	read_locale_file $langFile $prefix $3
}

function get_store_language_prefix() {
	echo "s$1$2"
}

function get_store_language_prefix_before_update_from_templates() {
	echo "b$1$2"
}

function read_derived_language_file() {
	local project="$1";
	local locale="$2";
	local langFile=$(get_file_name_from_locale $locale)
	local prefix=$(get_derived_language_prefix $project $locale)
	read_locale_file $langFile $prefix "$3"
}

function get_derived_language_prefix() {
	echo d$1$2
}