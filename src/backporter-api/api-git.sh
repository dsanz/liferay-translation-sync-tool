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
	    echo "Updating to HEAD $1"
		cd "$1"
		echo $(git branch 2>/dev/null | sed -n '/^\*/s/^\* //p')
		branch["$1"]=$(git branch 2>/dev/null | sed -n '/^\*/s/^\* //p')
		echo "  - Updating ${branch[$1]} branch from upstream"
		git pull upstream ${branch[$1]} > /dev/null 2>&1
		commit["$1"]=$(git rev-parse HEAD)
	else
		echo "  - $1 is not under GIT, unable to update"
	fi
	cd $pwd
}

function check_git() {
	update_to_head $source_dir
	update_to_head $target_dir

	do_commit=$(is_git_dir $target_dir)
	if [[ do_commit ]]; then
		echo "  - Backported files will be commited to $target_dir"
	fi
}

function commit_result() {
	if [[ $do_commit -eq 0 ]]; then
		echo "Committing resulting files"
		result_branch="${result_branch}_${branch[$source_dir]}_to_${branch[$target_dir]}_$(date +%Y%m%d%H%M%S)"
		refspec="origin/$result_branch"
		echo "  - Working on branch $result_branch"
		cd $2
		if [[ $(git branch | grep "$result_branch" | wc -l) -eq 1 ]]; then
			echo "  - Deleting old branch $result_branch"
			git branch -D $result_branch  > /dev/null 2>&1
		fi;
		echo "  - Creating branch $result_branch"
		message="Translations backported from ${branch[$source_dir]}:${commit[$source_dir]} to ${branch[$target_dir]}:${commit[$target_dir]}, by $product"
		git checkout -b $result_branch > /dev/null 2>&1
		echo "  - Commiting translation files to $result_branch"
		git commit -m "$message" Language*.properties > /dev/null 2>&1
		echo "  - Commiting review files to $result_branch"
		git add Language*.properties.review*
		git commit -m "$message [human review required]" Language*.properties.review* > /dev/null 2>&1
		if [[ $(git branch -r | grep "$refspec" | wc -l) -eq 1 ]]; then
			echo "  - Deleting remote branch $refspec"
			git push origin :"$refspec"  > /dev/null 2>&1
		fi
		echo "  - Pushing to remote branch"
		git push origin "$result_branch" > /dev/null 2>&1
		git checkout "${branch[$target_dir]}" > /dev/null 2>&1
	else
		echo "Resulting files won't be committed"
	fi
}
