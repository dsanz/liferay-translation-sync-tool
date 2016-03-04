# given a project and a language, reads the Language_xx.properties file
# present in current directory puts it into array T using the locale as prefix
function read_derived_language_file() {
	project="$1";
	locale="$2";
	langFile="$FILE$LANG_SEP$locale.$PROP_EXT"
	prefix=$(get_derived_language_prefix $project $locale)
	read_locale_file $langFile $prefix "$3"
}

function get_derived_language_prefix() {
	echo d$1$2
}