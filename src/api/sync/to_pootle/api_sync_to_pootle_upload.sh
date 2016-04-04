# this API allows to workaround a pootle bug so that new translations coming from a Language_*.properties file
# can be incorporated to the Pootle Database. This feature is used both from the pootle_manager (to post
# new tranlsations coming from source branches) and from the stand-alone version.

# common, base function for uploading a submission through pootle webui.
# It just checks if value is not auto-translated / auto-copied before publishing
# used from pootle manager as well as from the stand-alone version

function upload_submission_http() {
	key="$1"
	value="$2"
	storeId="$3"
	local path="$4"

	index=$(get_index $storeId $key)
	id=$(get_unitid $storeId $key)
	sourcef=$(get_sourcef $storeId $key)

	status_code=$(curl $CURL_OPTS -m 120 -w "%{http_code}" -d "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" -d "id=$id" -d "path=$path" -d  "pootle_path=$path" -d "source_f_0=$sourcef" -d  "store=$path" -d "submit=Submit" -d  "target_f_0=$value" -d "index=$index" "$PO_SRV$path/translate/?" 2> /dev/null)
	log -n "   ($status_code)"
	[[ $status_code == "200" ]]
}

function upload_submission_db() {
	key="$1"
	value="$2"
	storeId="$3"

	# TODO: update target word count and length. Update unit state to 200. Add submission for the user??
	update_targetf "$storeId" "$key" "$value"
}

# uploads a translation for a key in an specific project/language pair.
# storeId and path are pootle internal variables used to locate the project and language
# value is the actual translation for the given key.
function upload_submission() {
	key="$1"
	value="$2"
	storeId="$3"
	local path="$4"

	if is_translated_value "$value"; then
		logt 4 -n "publishing translation '$key': $value"
		$UPLOAD_SUBMISSION_FUNCTION "$key" "$value" "$storeId" "$path"
		check_command
	else
		logt 4 "Skipping untranslated key '$key': $value"
	fi
}

# this uploads all submissions from a given file, computed from a project/locale pair.
function upload_submissions() {
	locale="$2"
	project="$1"
	storeId=$(get_store_id $project $locale)
	local path=$(get_pootle_path $project $locale)
	filename=$(get_filename $locale)

	logt 3 "Posting the set of translations"

	checkTpl=false;
	if $3; then
		logt 4 "Checking existence of template file"
		templateName=$FILE.$PROP_EXT
		if [ -f $templateName ]; then
			read_locale_file $templateName "tpl"
			checkTpl=true;
			logt 4 "I'll use $templateName to detect untranslated strings and avoid posting them"
		fi;
	fi;

	done=false;
	until $done; do
		read line || done=true
		if is_key_line "$line" ; then
			[[ "$line" =~ $k_rexp ]] && key="${BASH_REMATCH[1]}"
			[[ "$line" =~ $v_rexp ]] && value="${BASH_REMATCH[1]}"
			if [ ! checkTpl ]; then
				upload_submission "$key" "$value" "$storeId" "$path"
			elif [[ ${T["tpl$key"]} != $value ]]; then
				upload_submission "$key" "$value" "$storeId" "$path"
			else
				logt 4 "Skipping untranslated key '$key': $value"
			fi
		fi
	done < $filename
}

# posts a file, including opening/closing session in pootle.
# intended to be called from the stand-alone version
function post_file() {
	project="$1"
	locale="$2"
	logt 2 "Posting '$locale' translations for $project"
	start_pootle_session
	upload_submissions "$1" "$2" true
	close_pootle_session
}

# posts a file without opening/closing session in pootle. Useful for posting a bunch of files.
# intended to be called from pootle-manager to upload new translations submitted to liferay code
function post_file_batch() {
	project="$1"
	locale="$2"
	logt 2 "Posting '$locale' translations for project $1"
	upload_submissions "$project" "$locale"
}

function post_derived_translations() {
	project="$1"
	derived_locale="$2"
	parent_locale="$3"

	prepare_output_dir $project
	logt 2 "Reading language files"
	logt 3 "Reading $derived_locale file"
	read_derived_language_file $project $derived_locale true
	logt 3 "Reading pootle store for parent language $parent_locale in project $project"
	read_pootle_store $project $parent_locale

	# TODO: try to read Language.properties to avoid uploading untranslated keys
	# best way to achieve this is calling upload_submissions with a filtered version of derived file
	storeId=$(get_store_id $project $derived_locale)
	local path=$(get_pootle_path $project $derived_locale)

	logt 2 "Uploading..."
	start_pootle_session
	for key in "${K[@]}"; do
		valueDerived=${T["d$project$derived_locale$key"]}
		valueParent=${T["s$project$parent_locale$key"]}
		if [[ "$valueDerived" != "$valueParent" ]]; then
			upload_submission "$key" "$valueDerived" "$storeId" "$path"
		fi;
	done;
	close_pootle_session
}
