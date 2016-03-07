function update_from_templates() {
	project="$1"
	src_dir="$2"

	logt 3 "Updating the set of translatable keys"
	logt 4 -n "Copying project files "
	cp "$src_dir/${FILE}.$PROP_EXT" "$PODIR/$project"
	check_command
	# Update database as well as file system to reflect the latest version of translation templates
	logt 4 "Updating Pootle templates (this may take a while...)"
	call_manage "update_from_templates" "--project=$project" "-v 0"
}

function update_pootle_db_from_templates() {
	logt 1 "Updating pootle database..."
	for project in "${!AP_PROJECT_NAMES[@]}"; do
		src_dir=${AP_PROJECT_SRC_LANG_BASE["$project"]}
		logt 2 "$project: "
		update_from_templates $project $src_dir
	done
}

function update_pootle_db_from_templates_repo_based() {
	logt 1 "Updating pootle database..."
	for project in "${GIT_ROOT_POOTLE_PROJECT_NAME[@]}";
	do
		logt 2 "$project: "
		project_list="$(echo ${AP_PROJECTS_BY_GIT_ROOT["$git_root"]} | sed 's: :\n:g' | sort)"
		projects=$(echo "$project_list" | wc -l)
		while read source_code_project; do
			logt 3 "Adding $source_code_project template"
			cat ${AP_PROJECT_SRC_LANG_BASE[$source_code_project]}/$FILE.$EXT >> $PODIR/$project/$FILE.$EXT
			check_command
		done <<< "$project_list"
		update_from_templates $project $PODIR/$project
	done
}

# this API allows to workaround a pootle bug so that new translations coming from a Language_*.properties file
# can be incorporated to the Pootle Database. This feature is used both from the pootle_manager (to post
# new tranlsations coming from source branches) and from the stand-alone version.

# common, base function for uploading a submission through pootle webui.
# It just checks if value is not auto-translated / auto-copied before publishing
# used from pootle manager as well as from the stand-alone version

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
		index=$(get_index $storeId $key)
		id=$(get_unitid $storeId $key)
		sourcef=$(get_sourcef $storeId $key)

		status_code=$(curl $CURL_OPTS -m 120 -w "%{http_code}" -d "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" -d "id=$id" -d "path=$path" -d  "pootle_path=$path" -d "source_f_0=$sourcef" -d  "store=$path" -d "submit=Submit" -d  "target_f_0=$value" -d "index=$index" "$PO_SRV$path/translate/?" 2> /dev/null)
		[[ $status_code == "200" ]]
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