#!/bin/bash

export HOME_DIR="$(dirname $(readlink -f $BASH_SOURCE))"

. $HOME_DIR/../base_env.sh

# regexp with matches the key in a key/value pair text line. Works even if value is empty
declare k_rexp="^([^=]+)="

# regexp with matches the value in a key/value pair text line. Works even if value is empty
declare v_rexp="^[^=]+=(.*)"

done=false;
until $done; do
	read line || done=true;
	[[ "$line" =~ $k_rexp ]] && project_name="${BASH_REMATCH[1]}"
	[[ "$line" =~ $v_rexp ]] && project_description="${BASH_REMATCH[1]}"
	# use a direct call to make sure last parameter is properly passed
	cd $SYNC_TOOL_HOME
	$BASH_HOME/bash pootle-manager.sh -np $project_name "$project_description" 2>&1
done < $HOME_DIR/project.properties