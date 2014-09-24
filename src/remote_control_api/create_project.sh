#!/bin/bash

. remote_control_api/base_env.sh

# regexp with matches the key in a key/value pair text line. Works even if value is empty
declare -g k_rexp="^([^=]+)="

# regexp with matches the value in a key/value pair text line. Works even if value is empty
declare -g v_rexp="^[^=]+=(.*)"

done=false;
until $done; do
	read line || done=true;
	[[ "$line" =~ $k_rexp ]] && project_name="${BASH_REMATCH[1]}"
	[[ "$line" =~ $v_rexp ]] && project_description="${BASH_REMATCH[1]}"
	run_sync_tool "-np" "$project_name" "$project_description"
done < $HOME_DIR/project.properties