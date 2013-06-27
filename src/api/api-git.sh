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