#!/bin/bash

declare -Ag commit
declare -Ag branch

declare -g use_git=0
declare -g result_branch="translations_backport"
declare -g refspec="origin/$result_branch"
declare -g do_commit=1

declare pwd=$(pwd)

function update_to_head() {
	if is_git_dir "$1"; then
	    logt 3 "Updating to HEAD $1"
		cd "$1"
		branch["$1"]=$(git branch 2>/dev/null | sed -n '/^\*/s/^\* //p')
		logt 4 -n "git pull upstream ${branch[$1]}"
		git pull upstream ${branch[$1]} > /dev/null 2>&1
		check_command
		commit["$1"]=$(git rev-parse HEAD)
	else
		logt 3 "$1 is not under GIT, unable to update"
	fi
	cd $pwd
}

function check_git() {
    logt 2 "Checking branches for backporting [$1 --> $2]"
    if [[ $use_git == 0 ]]; then
		logt 3 "Using git..."
	    update_to_head $1
	    update_to_head $2

	    do_commit=$(is_git_dir $2)
	    if [[ do_commit ]]; then
    		logt 3 "Backported files will be commited to $target_dir"
    	fi
   	else
		logt 3 "Not using git"
	fi
}

function commit_result() {
	if [[ $do_commit -eq 0 ]]; then
		logt 2 "Committing files (base: $1)"
		result_branch="${result_branch}_${branch[$source_dir]}_to_${branch[$target_dir]}_$(date +%Y%m%d%H%M%S)"
		refspec="origin/$result_branch"
		logt 3 "Working on branch $result_branch"
		cd $1
		if [[ $(git branch | grep "$result_branch" | wc -l) -eq 1 ]]; then
			logt 4 -n "Deleting old branch $result_branch"
			git branch -D $result_branch  > /dev/null 2>&1
            check_command
		fi;
		logt 4 -n "Creating branch $result_branch"
		message="Translations backported from ${branch[$source_dir]}:${commit[$source_dir]} to ${branch[$target_dir]}:${commit[$target_dir]}, by $product"
		git checkout -b $result_branch > /dev/null 2>&1
		check_command

		logt 4 -n "Commiting translation files to $result_branch"
		git commit -a -m "$message" > /dev/null 2>&1
		check_command

		logt 4 -n "Commiting review files to $result_branch"
		for reviewFile in $(git status --porcelain -uall | grep ".review." | cut -f2- -d' '); do
		    git add $reviewFile
		done
		git commit -a -m "$message [human review required]" > /dev/null 2>&1
		check_command

		if [[ $(git branch -r | grep "$refspec" | wc -l) -eq 1 ]]; then
			logt 4 -n "Deleting remote branch $refspec"
			git push origin :"$refspec"  > /dev/null 2>&1
			check_command
		fi
		logt 4 -n "Pushing to remote branch"
		git push origin -f "$result_branch" > /dev/null 2>&1
		check_command

		git checkout "${branch[$target_dir]}" > /dev/null 2>&1
	else
		logt 2 "Resulting files won't be committed"
	fi
}
