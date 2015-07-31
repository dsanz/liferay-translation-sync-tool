function add_git_root() {
	git_root_dir="$1"
	pr_reviewer="$2"
	sync_branch="$3"

	[[ "$pr_reviewer" == "" ]] && pr_reviewer=$DEFAULT_PR_REVIEWER;
	[[ "$sync_branch" == "" ]] && sync_branch=$DEFAULT_SYNC_BRANCH;

	GIT_ROOTS["$git_root_dir"]=$sync_branch;
	PR_REVIEWER["$git_root_dir"]=$pr_reviewer;
}