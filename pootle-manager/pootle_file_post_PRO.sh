declare -x -r PO_HOST="vm-9.liferay.com"
declare -x -r PO_PORT="80"
declare -x -r PO_SRV="http://$PO_HOST:$PO_PORT/pootle"
declare -x -r PO_COOKIES="$TMP_DIR/${PO_HOST}_${PO_PORT}_cookies.txt"
declare -x -r PO_USER="pootle"
declare -x -r PO_PASS="Foxa26sl"
declare -x -r DB_NAME="pootle"

    close_pootle_session() {
        # get logout page and delete cookies
        echo -n "    Closing pootle session... "
        curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" "$PO_SRV/accounts/logout" > /dev/null
        check_command
        #[ -f "$PO_COOKIES" ] && rm "$PO_COOKIES"
    }

    start_pootle_session() {
        echo "  Opening new pootle session"
        close_pootle_session
        # 1. get login page (and cookies)
        echo -n "    Accessing Pootle login page... "
        curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" "$PO_SRV/accounts/login" > /dev/null
        check_command
        # 2. post credentials, including one received cookie
        echo -n "    Posting credentials... "
        curl -s -b "$PO_COOKIES" -c "$PO_COOKIES" -d "username=$PO_USER;password=$PO_PASS;csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" "$PO_SRV/accounts/login" > /dev/null
        check_command
    }


## specific functions (above this everything was copied from pootle_manager.sh)

    # given the storeId and the language key (unitId) returns the index of that translation unit in the DB
    get_index() {
	local i=$(mysql $DB_NAME -s  -e "select pootle_store_unit.index from pootle_store_unit where store_id=\"$1\" and unitid=\"$2\";"  | cut -d : -f2)
	echo $i;
    }

    # given the storeId and the language key (unitId) returns the id (pk)  of the translation unit in the DB
    get_unitid() {
        local i=$(mysql $DB_NAME -s  -e "select pootle_store_unit.id from pootle_store_unit where store_id=\"$1\" and unitid=\"$2\";"  | cut -d : -f2)
        echo $i;
    }

    # given the storeId and the language key (unitId) returns the source_f field of that translation unit in the DB, which stores the default (English) translation of the key
    get_sourcef() {
        local i=$(mysql $DB_NAME -s  -e "select pootle_store_unit.source_f from pootle_store_unit where store_id=\"$1\" and unitid=\"$2\";"  | cut -d : -f2)
        echo $i;
    }

    # given a locale name such as "pt_BR" returns the file name "Language_pt_BR.properties"
    get_filename(){
        local i="Language_$1.properties"
        echo $i;
    }

    # given a project name and a locale, returns the path of the store for translations of that project in that language
    # this path allows to query the table pootle_store_store by "pootle_path" and get the storeId
    # it's also required for preparing the post (see upload_submission)
    get_pootle_path() {
        project="$1"
        locale="$2"
        # value example: "/pt_BR/portal/Language_pt_BR.properties"
        local i="/$locale/$project/$(get_filename $locale)"
	echo $i;
    }

    # given the project name and a locale, returns the storeId of the store which has all translations of that project in that language
    get_store_id() {
        project="$1"
        locale="$2"
        local i=$(mysql $DB_NAME -s  -e "select pootle_store_store.id from pootle_store_store where pootle_path=\"$(get_pootle_path $project $locale)\";"  | cut -d : -f2)

        echo $i;
    }

    upload_submission() {
	key="$1"
        value="$2"
        storeId="$3"
        path="$4"
        index=$(get_index $storeId $key)
        id=$(get_unitid $storeId $key)
	sourcef=$(get_sourcef $storeId $key)

        echo "[`date`] Posting $key=$value"
	curl -s -b "$PO_COOKIES" -c "$PO_COOKIES"  -d "csrfmiddlewaretoken=`cat ${PO_COOKIES} | grep csrftoken | cut -f7`" -d "id=$id" -d "path=$path" -d  "pootle_path=$path" -d "source_f_0=$sourcef" -d  "store=$path" -d "submit=Submit" -d  "target_f_0=$value" -d "index=$index" "$PO_SRV$path/translate/?" > /dev/null
    }

    get_key() {
	echo $1 | sed s/=.*//
    }

    get_value() {
	echo $1 | sed -r s/^[^=]+=//
    }

    readfile() {
	locale="$2"
        project="$1"
        storeId=$(get_store_id $project $locale)
        path=$(get_pootle_path $project $locale)
        filename=$(get_filename $locale)

	echo "Utility for posting translations via HTTP"
	echo "  project : $project"
	echo "  locale  : $locale"
        echo "  storeid : $storeId"
	echo "  path    : $path"
	echo "  filename: $filename"

	echo "[`date`] submitting keys to project '$project' read from '$filename'..."
	start_pootle_session
	while read line; do 
	    # debug: echo "L: $line"
	    key=$(echo $line | sed s/=.*//)
            value=$(echo $line | sed -r s/^[^=]+=//)
	    upload_submission "$key" "$value" "$storeId" "$path"
	done < $filename
        close_pootle_session
    }

   readfile $@
 
# start_pootle_session
#upload_submission javax.portlet.title.134 ÑEEE
#close_pootle_session


# dado un commit con traducciones, obtenemos el valor así:
# git diff commit  | grep ^+ | sed s/^+//g | while read line;do echo $line | sed s/^[^=]+=//; done
   	
