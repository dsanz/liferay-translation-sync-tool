

function pull_source_code() {
	logt 1 "Preparing project source dirs..."
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		goto_branch_tip "$base_src_dir"
	done;
}

function do_commit() {
	reuse_branch=$1
	submit_pr=$2
	commit_msg=$3
	logt 1 "Committing results (reusing branch?=${reuse_branch}, will submit pr?=$submit_pr)"
	for base_src_dir in "${!GIT_ROOTS[@]}"; do
		cd $base_src_dir
		logt 2 "$base_src_dir"

		logt 3 "Adding untracked files"
		added_language_files=$(git status -uall --porcelain | grep "??" | grep $FILE | cut -f 2 -d' ')
		if [[ $added_language_files != "" ]]; then
			for untracked in $added_language_files; do
				logt 4 -n "git add $untracked"
				git add "$untracked"
				check_command
			done
		else
			logt 4 "No untracked files to add"
		fi;
		if something_changed; then
			if exists_branch "$EXPORT_BRANCH" "$base_src_dir"; then
				if $reuse_branch; then
					logt 3 "Reusing export branch"
					logt 4 -n "git checkout $EXPORT_BRANCH"
					git checkout "$EXPORT_BRANCH" > /dev/null 2>&1
					check_command
					create_branch=false;
				else
					logt 3 "Deleting old export branch"
					logt 4 -n "git branch -D $EXPORT_BRANCH"
					git branch -D "$EXPORT_BRANCH" > /dev/null 2>&1
					check_command
					create_branch=true;
				fi
			else
				create_branch=true;
			fi

			if $create_branch; then
				sync_branch="${GIT_ROOTS["$base_src_dir"]}"
				logt 3 "Creating new export branch from $sync_branch"
				logt 4 -n "git checkout $sync_branch"
				git checkout $sync_branch > /dev/null 2>&1
				check_command
				logt 4 -n "git checkout -b $EXPORT_BRANCH"
				git checkout -b "$EXPORT_BRANCH" > /dev/null 2>&1
				check_command
			fi
			msg="$LPS_CODE $commit_msg [by $product]"
			logt 3 "Committing..."
			logt 4 -n "git commit -a -m $msg"
			git commit -a -m "$msg" > /dev/null 2>&1
			check_command
		else
			logt 3 "No changes to commit!!"
		fi
		if $submit_pr; then
			submit_pull_request $base_src_dir
		fi
	done;
}

function submit_pull_request() {
	base_src_dir="$1"
	logt 3 -n "Deleting remote branch origin/$EXPORT_BRANCH"
	git push origin ":$EXPORT_BRANCH" > /dev/null 2>&1
	check_command

	logt 3 -n "Pushing remote branch origin/$EXPORT_BRANCH"
	git push origin "$EXPORT_BRANCH" > /dev/null 2>&1
	check_command

	reviewer="${PR_REVIEWER[$base_src_dir]}"
	sync_branch="${GIT_ROOTS[$base_src_dir]}"
	logt 3 -n "Sending pull request to $reviewer:$sync_branch"
	pr_url=$($HUB_BIN pull-request -m "Translations from pootle. Automatic PR sent by $product" -b "$reviewer":"$sync_branch" -h $EXPORT_BRANCH)
	check_command

	logt 4 "Pull request URL: $pr_url"

	logt 3 -n "git checkout $sync_branch"
	git checkout $sync_branch > /dev/null 2>&1
	check_command
}
