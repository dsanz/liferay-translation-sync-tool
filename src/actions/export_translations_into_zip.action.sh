function generate_zip_from_translations() {
	export_pootle_translations_to_po_dir

	timestamp="$(date +%F_%H-%M-%S)"
	for locale in "${POOTLE_PROJECT_LOCALES[@]}"; do
		generate_locale_zip_from_translations $locale $timestamp
	done
}

function generate_locale_zip_from_translations() {
	locale="$1"
	timestamp="$2"
	locale_file="$FILE$LANG_SEP$locale.$PROP_EXT"
	zip_file="$locale_$timestamp.zip"

	logt 2 "Compressing $locale_file for all projects into $zip_file"
	cd $PODIR
	find . -name $locale_file -print | zip $TMP_PROP_OUT_DIR/$zip_file -@
	logt 2 "Please find result file in $TMP_PROP_OUT_DIR/$zip_file"
}
