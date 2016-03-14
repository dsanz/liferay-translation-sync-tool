function update_from_templates() {
	project="$1"
	src_dir="$2"

	logt 3 "Updating the set of translatable keys for project $project"

	if [[ "$src_dir" != "$PODIR/$project" ]]; then
		logt 4 -n "Copying template to PODIR "
		cp "$src_dir/${FILE}.$PROP_EXT" "$PODIR/$project"
		check_command
	else
		logt 4 "I've been instructed to sync directly from PODIR"
	fi
	# Update database as well as file system to reflect the latest version of translation templates
	logt 4 "Updating Pootle templates (this may take a while...)"

	# this call seems to update all languages from templates, except the templates itself
	# this leads to poor exports as exported template is wrong
	# for this reason, we call this on a per-language basis
	read_pootle_projects_and_locales

	# TODO: see what happens when units have OBSOLETE status (-100)
	for locale in "${POOTLE_PROJECT_LOCALES[@]}"; do
		storeId=$(get_store_id $project $locale)
		template_length=$(count_keys "$PODIR/$project/${FILE}.$PROP_EXT")
		while : ; do
			call_manage "update_from_templates" "--project=$project" "--language=$locale" "-v 0"
			store_unit_count=$(count_targets $storeId)
			logt 4 "Language file has $template_length keys. Store $storeId has $store_unit_count keys"
		 	#[[ $template_length > $store_unit_count ]] || break
		 	# allow the store to have one key more or less than the incoming template
			(( store_unit_count <= template_length + 1 )) && (( store_unit_count >= template_length - 1 )) && break;
		 	[[ "$locale" == "sr_RS_latin" ]] && break
		done
	done;

	session_opened=$(is_admin_session_opened)

	if ! $session_opened; then
		start_pootle_session
	fi

	logt 4 -n "Telling pootle to rescan template file"
	status_code=$(curl $CURL_OPTS -m 120 -w "%{http_code}" -d "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" -d "scan_files=Rescan project files" "$PO_SRV/templates/$project/admin_files.html" 2> /dev/null)
	[[ $status_code == "200" ]]
	check_command

	if ! $session_opened; then
		close_pootle_session
	fi
}

function update_pootle_db_from_templates() {
	logt 1 "Updating pootle database from repository-based project set ..."

	check_dir "$PODIR/$POOTLE_PROJECT_ID/"
	rm -f $PODIR/$POOTLE_PROJECT_ID/$FILE.$PROP_EXT 2>&1

	logt 2 "Pootle $POOTLE_PROJECT_ID (git root: $git_root): will update templates from ${#AP_PROJECT_NAMES[@]} projects"

	for source_code_project in "${!AP_PROJECT_NAMES[@]}"; do
		logt 3 -n "Adding $source_code_project template"
		# TODO: make sure we have a new line after each cat even id source file does not
		cat ${AP_PROJECT_SRC_LANG_BASE[$source_code_project]}/$FILE.$PROP_EXT >> $PODIR/$POOTLE_PROJECT_ID/$FILE.$PROP_EXT
		check_command
	done

	update_from_templates $POOTLE_PROJECT_ID $PODIR/$POOTLE_PROJECT_ID
}

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

function clean_temp_input_dirs() {
	logt 1 "Preparing project input working dirs..."
	logt 2 "Cleaning general input working dir"
	clean_dir "$TMP_PROP_IN_DIR/"
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		logt 2 "$project: cleaning input working dirs"
		clean_dir "$TMP_PROP_IN_DIR/$project"
	done
}