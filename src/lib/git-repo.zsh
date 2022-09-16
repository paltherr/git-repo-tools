#!/bin/zsh

. zfun.zsh;

################################################################################

: ${RELEASE_BRANCH:=main};
: ${CHANGELOG_FILE:=CHANGELOG.md};
: ${LATEST_TAG:=latest};
: ${HOMEBREW_FORMULA_FILE:=.homebrew-formula};

GH_API=(gh api -H "Accept: application/vnd.github+json");
GH_REPO=repos/{owner}/{repo};

################################################################################

# Print the specified arguments as is.
function show() {
    echo -E - "$@";
}

# Print the specified arguments as is in the color specified by the
# first argument.
#
# Colors: red green yellow blue magenta cyan black white.
function show-colored() {
    local color=$1; shift 1;
    print -nP "%F{$color}";
    show "$@";
    print -nP "%f";
}

# Prints the specified arguments and runs them as a command.
function run() {
    show-colored magenta "${(q+)@}";
    "$@";
}

################################################################################

# Computes "self_home", the directory of the file pointed to by the
# specified file "self", and "self_name", the name of the last link in
# the chain of links or the name of the "self" if it isn't a link.
fun compute-self-home-and-name self :{
    local name=$self:t;
    local link;
    while link=$(readlink $self:a); do
        name=$self:t;
        case $link in
            /* ) self=$link;;
            *  ) self=$self:h/$link;;
        esac;
    done;
    typeset -g self_home=$self:A:h;
    typeset -g self_name=$name;
}

# Prints the specified question, awaits a yes/no answer, and exits in
# case of a negative answer.
fun confirm question :{
    local choice;
    read -sq "choice?$question " || { echo $choice; exit 1; }
    echo $choice;
}

################################################################################

# Prints the head commit of the specified branch.
fun head-commit branch :{
    git rev-parse $branch;
}

# Prints the head commit of the specified branch on GitHub.
fun head-commit-remote branch :{
    $GH_API $GH_REPO/branches/$branch --jq .commit.sha;
}

# Amends the head commit if it can still be amended on GitHub.
fun head-commit-amend :{
    local branch=$(git branch --show-current);
    local head_commit_local=$(head-commit $branch);
    local head_commit_remote=$(head-commit-remote $branch);
    echo git merge-base --is-ancestor $head_commit_remote $head_commit_local;
    $(git merge-base --is-ancestor $head_commit_remote $head_commit_local) ||
        abort "Local branch is behind remote branch or has diverged";
    run git commit --amend;
    if [[ $head_commit_remote = $head_commit_local ]]; then
        run git push --force-with-lease origin $branch;
    fi;
}

################################################################################

# Tests whether the specified tag is present.
fun tag-test-presence tag :{
    [[ $(git tag --list $tag) = $tag ]];
}

# Tests whether the specified tag is absent.
fun tag-test-absence tag :{
    [[ -z $(git tag --list $tag) ]];
}

# Asserts the presence of the specified tag.
fun tag-assert-presence tag :{
    tag-test-presence $tag || abort "The tag ${(qqq)tag} doesn't exist.";
}

# Asserts that the specified tag is present on GitHub.
fun tag-assert-presence-remote tag :{
    $GH_API $GH_REPO/git/refs/tags/$tag > /dev/null || abort "The tag ${(qqq)tag} doesn't exist on GitHub.";
}

# Asserts the absence of the specified tag.
fun tag-assert-absence tag :{
    tag-test-absence $tag || abort "The tag ${(qqq)tag} already exists.";
}

# Creates the specified tag with the specified annotation and target
# and pushes it to "origin".
fun tag-create tag annotation target :{
    run git tag --annotate --cleanup=verbatim --message=$annotation $tag $target;
    run git push origin $tag;
}

# Updates the tag specified with the specified annotation and target and pushes
# it to "origin".
fun tag-update tag annotation target :{
    run git tag --annotate --cleanup=verbatim --message=$annotation --force $tag $target;
    run git push --force origin $tag;
}

# Deletes the specified tag and pushes the change to "origin".
fun tag-delete tag :{
    run git tag --delete $tag;
    run git push --delete origin $tag;
}

################################################################################

# Prints the latest tag.
fun latest-tag :{
    echo $LATEST_TAG;
}

# Updates, locally and remotely, the latest tag to refer the specified
# version.
fun latest-tag-update version :{
    local latest_tag=$(latest-tag);
    local release_tag=$(release-tag $version);
    tag-assert-presence $release_tag;
    tag-update $latest_tag $release_tag $release_tag^{};
}

################################################################################

# Confirms that the specified version matches the expected syntax or
# that the user agrees with the discrepancy and exits otherwise.
fun version-confirm-syntax version :{
    local match mbegin mend;
    if [[ $version =~ '^(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)$' ]]; then
        local major=$match[1];
        local minor=$match[2];
        local patch=$match[3];
    else
        confirm "The version ${(qqq)version} doesn't match the syntax <major>.<minor>.<patch>. Proceed anyway?";
    fi;
}

################################################################################

# Prints the release title for the specified version.
fun release-title version :{
    local repo_name=$($GH_API $GH_REPO --jq .name);
    show $repo_name-$version;
}

# Prints the release notes for the specified version. The notes are
# extracted from "CHANGELOG.md". Notes for a version are expected to
# start with the following line:
#
# ## [<version>](https://github.com/<owner>/<repo>/releases/tag/v<version>) - <YYYY-MM-DD>
fun release-notes version :{
    local logs=("${(@f)$(cat $CHANGELOG_FILE)}");
    local start=${logs[(i)## \[$version\]\(*\) - 20??-??-??]};
    [[ $start -le $#logs ]] || abort "Could not find version ${(qqq)version} in file $CHANGELOG_FILE";
    local end=$((${logs[(ib:start+1:)## \[*.*.*\]\(*\) - ????-??-??]}-1));
    while [[ $logs[end] = "" ]]; do end=$((end-1)); done;
    local header=$logs[start];
    [[ $header = *\[$version\]\(*/v$version\)*20??-??-?? ]] || abort "The changelog header link contains the wrong version.";
    local date=$header[-10,-1];
    show "Release date: $date";
    show "${(F)logs[start+1,end]}";
}

# Prints the release tag for the specified version.
fun release-tag version :{
    show v$version;
}

################################################################################

# Creates or updates, locally and remotely, the release tag for the
# specified version and target.
fun release-tag-insert operation version target :{
    local release_tag=$(release-tag $version);
    local release_notes=$(release-notes $version);
    show-colored blue "Release notes:";
    show-colored cyan $release_notes;
    tag-$operation $release_tag $release_notes $target;
}

# Creates, locally and remotely, the release tag for the specified
# version. The tag is annotated with the release notes.
fun release-tag-create version :{
    version-confirm-syntax $version;

    [[ $(git branch --show-current) = $RELEASE_BRANCH ]] ||
        abort "Not on the release branch ${(qqq)RELEASE_BRANCH}.";

    local head_commit_subject=$(git log -1 --format=%s);
    local expected_subject="Version $version";
    [[ $head_commit_subject = $expected_subject ]] ||
        confirm "The head commit subject should be ${(qqq)expected_subject}, found: ${(qqq)head_commit_subject}. Proceed anyway?";

    local head_commit_files=("${(@f)$(git diff-tree --no-commit-id --name-only -r HEAD)}");
    [[ $head_commit_files[(I)$CHANGELOG_FILE] -gt 0 ]] ||
        confirm "The head commit didn't modify ${(qqq)CHANGELOG_FILE}. Proceed anyway?";

    local head_commit_local=$(head-commit $RELEASE_BRANCH);
    local head_commit_remote=$(head-commit-remote $RELEASE_BRANCH);
    [[ $head_commit_local = $head_commit_remote ]] ||
        abort "The local release branch ${(qqq)RELEASE_BRANCH} isn't synced to the remote one.";

    local release_tag=$(release-tag $version);
    tag-assert-absence $release_tag;
    release-tag-insert create $version main;
}

# Updates, locally and remotely, the tag for the specified version.
# The tag is annotated with the release notes.
fun release-tag-update version :{
    local release_tag=$(release-tag $version);
    tag-assert-presence $release_tag;
    release-tag-insert update $version $release_tag^{};
}

# Deletes, locally and remotely, the tag for the specified version.
fun release-tag-delete version :{
    local release_tag=$(release-tag $version);
    tag-assert-presence $release_tag;
    ! $(gh release view $release_tag >/dev/null) ||
        abort "A release still exists for the version ${(qqq)version}.";
    tag-delete $release_tag;
}

################################################################################

# Creates or updates the release for the specified version.
fun release-insert operation version :{
    local release_tag=$(release-tag $version);
    local release_title=$(release-title $version);
    local release_notes=$(release-notes $version);
    show-colored blue "Release notes:";
    show-colored cyan $release_notes;
    run gh release $operation $release_tag --title $release_title --notes $release_notes;
}

# Creates the release for the specified version.
fun release-create version :{
    local release_tag=$(release-tag $version);
    tag-assert-presence $release_tag;
    tag-assert-presence-remote $release_tag;
    local release_tag_sha_local=$(git rev-parse $release_tag);
    local release_tag_sha_remote=$($GH_API $GH_REPO/git/refs/tags/$release_tag --jq .object.sha);
    [[ $release_tag_sha_local = $release_tag_sha_remote ]] ||
        abort "The local release tag ${(qqq)release_tag} isn't synced to the remote one.";
    release-insert create $version;
}

# Updates the release for the specified version.
fun release-update version :{
    release-insert edit $version;
}

# Deletes the release for the specified version.
fun release-delete version :{
    local release_tag=$(release-tag $version);
    run gh release delete $release_tag;
}

################################################################################

# Prints the homebrew formula.
fun homebrew-formula-full-name :{
    echo ${HOMEBREW_FORMULA:-$(cat $HOMEBREW_FORMULA_FILE)};
}

# Updates the homebrew formula source to use the release for the
# specified version. The file ".homebrew-formula" is expected to
# contain the full name of the formula.
fun homebrew-formula-update version :{
    local release_tag=$(release-tag $version);
    tag-assert-presence-remote $release_tag;

    local release_repo_name=$($GH_API $GH_REPO --jq .name);
    local release_repo_full_name=$($GH_API $GH_REPO --jq .full_name);

    local archive_file_suffix=".tar.gz";
    local archive_file=$release_tag$archive_file_suffix;
    local archive_url_prefix="https://github.com/$release_repo_full_name/archive/";
    local archive_url=$archive_url_prefix$archive_file;

    local match mbegin mend;
    [[ $(homebrew-formula-full-name) =~ '^([^/]+)/([^/]+)/([^/]+)$' ]] ||
        abort "The formula ${(qqq)brew_formula} doesn't match the pattern \"<owner>/<repo>/<name>\".";
    local brew_repo_name=homebrew-$match[2];
    local brew_repo_full_name=$match[1]/$brew_repo_name;
    local brew_repo_file=Formula/$match[3].rb;

    local srcdir=$PWD;
    local tmpdir=$(mktemp -d /tmp/$self_name-XXXXXX);
    run cd $tmpdir;

    run curl --silent --show-error --location --remote-name $archive_url;
    local archive_sha256=$(cat $archive_file | openssl sha256);

    run git clone git@github.com:$brew_repo_full_name.git;
    run cd $tmpdir/$brew_repo_name;

    local formula_lines=("${(@f)$(cat $brew_repo_file)}");

    local formula_url_line=${formula_lines[(i)*[[:space:]]url[[:space:]]*$archive_url_prefix*$archive_file_suffix*]};
    [[ $formula_url_line -le $#formula_lines ]] ||
        abort "Could not locate \"url\" line in file ${(qqq)$(echo $tmpdir/$brew_repo_name/$brew_repo_file)}.";
    run sed -e "$formula_url_line s!\\(.*$archive_url_prefix\\)v0....\\($archive_file_suffix.*\\)!\\1$release_tag\\2!" -i "" $brew_repo_file;

    local formula_sha256_line=${formula_lines[(i)*[[:space:]]sha256[[:space:]]*]};
    [[ $formula_sha256_line -le $#formula_lines ]] ||
        abort "Could not locate \"sha256\" line in file ${(qqq)$(echo $tmpdir/$brew_repo_name/$brew_repo_file)}.";
    run sed -e "$formula_sha256_line s!\\(.* sha256 .*\"\\)[0-9a-z]*\\(\".*\\)!\\1${archive_sha256}\\2!" -i "" $brew_repo_file;

    run git diff;
    run git add $brew_repo_file;
    run git commit -m "$release_repo_name $version";
    run git push;

    run cd $srcdir;
    run rm -r $tmpdir/$archive_file;
    run rm -rf $tmpdir/$brew_repo_name;
    run rmdir $tmpdir;
}

################################################################################

function main() {
    local SELF=$ZSH_ARGZERO;
    local self_home self_name; compute-self-home-and-name $SELF;
    case $self_name in
        gr-* ) ${self_name#gr-} "$@";;
        *    ) abort "Unrecognized command: $self_name";;
    esac;
}

main "$@";

################################################################################
