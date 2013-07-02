#!/bin/bash

function exists_branch() {
	branch_name="$1"
	src_dir="$2"
	old_dir=$(pwd)
	cd $src_dir
	rexp="\b$branch_name\b"
	branches="$(git branch | sed 's/\*//g')"
	cd $old_dir
	[[ "$branches" =~ $rexp ]]
}

function is_git_dir() {
	cd $1;
	git rev-parse --git-dir > /dev/null 2>&1
	[[ $? -eq 0 ]]
}

function something_changed() {
    [[ $(git diff | wc -l) -gt 0 ]]
}

function goto_master() {
    cd $1
    logt 3 "Going master for $1"
    logt 4 -n "git reset --hard HEAD"
    git reset --hard HEAD > /dev/null 2>&1
    check_command
    logt 4 -n "git clean -df"
    git clean -df  > /dev/null 2>&1
    check_command
    logt 4 -n "git checkout -- ."
    git checkout -- .  > /dev/null 2>&1
    check_command
    logt 4 -n "git checkout master"
    git checkout master  > /dev/null 2>&1
    check_command
    logt 4 -n "git pull upstream master"
    git pull upstream master  > /dev/null 2>&1
    check_command
}

