#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Set variables from their all-caps versions, taking defaults from config file
set_vars() {
    local config_file=$1
    local vars=$(yq r "$1" --printMode p '*')
    readarray -t varsArr <<< "$vars"
    for var in "${varsArr[@]}"; do
        varCaps="${var^^}"
        if [ -z ${!varCaps+x} ]; then
            eval "$var"=$(yq r "$config_file" "$var.default")
        else
            eval "$var"="${!varCaps}"
        fi
    done
}

main() {
    git_init

    git clone --single-branch --branch "$git_branch" "https://$github_token@github.com/$github_owner/$github_repo"
    pushd "$github_repo" > /dev/null

    einfo "Discovering changed actions ..."
    local changed_actions=()
    readarray -t changed_actions <<< "$(lookup_changed_actions)"

    if [[ -n "${changed_actions[*]}" ]]; then
        for action in "${changed_actions[@]}"; do
            if [[ -d "$actions_dir/$action" ]]; then
                local current_tag=$(lookup_latest_tag $action)
                if [[ "$current_tag" == '' ]]; then
                    local new_semver="0.0.0"
                else
                    local current_semver=${current_tag#"$action-"}
                    local new_semver=$(semver bump $version_bump_level $current_semver)
                fi
                set_action_version "$action" "$new_semver"
                tag_action "$action" "$new_semver"
            else
                ewarn "Action '$action' no longer exists in repo. Skipping it..."
            fi
        done
        commit_and_push_changes
    else
        einfo "Nothing to do. No action changes detected."
    fi

    popd > /dev/null
}

git_init() {
    git config --global user.name "$git_user"
    git config --global user.email "$git_email"
}

lookup_latest_tag() {
    local action="$1"
    git fetch --tags > /dev/null 2>&1

    edebug "Looking for latest tag for $action"
    git for-each-ref --sort=-taggerdate --count=1 --format '%(refname:lstrip=-1)' "refs/tags/$action-*"
}

filter_actions() {
    while read action; do
        [[ ! -d "$actions_dir/$action" ]] && continue
        local file="$actions_dir/$action/action.yml"
        if [[ -f "$file" ]]; then
            echo $action
        else
            ewarn "$file is missing, assuming that '$action' is not a GitHub action. Skipping."
        fi
    done
}

lookup_changed_actions() {
    #look for changed files in the latest commit
    local changed_files
    changed_files=$(git diff-tree --no-commit-id --name-only -r $(git rev-parse HEAD) -- $actions_dir)
    cut -d '/' -f '2' <<< "$changed_files" | uniq | filter_actions
}

set_action_version() {
    local action="$1"
    local version="$2"

    einfo "Updating action.yml of $action to point to the '$version' tag"
    yq w -i "actions/$action/action.yml" 'runs.image' "$docker_repo/$action:$version"
}

tag_action() {
    local action="$1"
    local version="$2"
    local tag="$action-$version"

    einfo "Creating tag '$tag'"
    git tag "$tag"
}

commit_and_push_changes() {
    einfo 'Pushing changes and tags...'
    git add -u
    git commit -am "update version(s)"
    git push && git push --tags
}

colblk='\033[0;30m' # Black - Regular
colred='\033[0;31m' # Red
colgrn='\033[0;32m' # Green
colylw='\033[0;33m' # Yellow
colpur='\033[0;35m' # Purple
colrst='\033[0m'    # Text Reset

### verbosity levels
silent_lvl=0
crt_lvl=1
err_lvl=2
wrn_lvl=3
ntf_lvl=4
inf_lvl=5
dbg_lvl=6

## esilent prints output even in silent mode
function esilent () { verb_lvl=$silent_lvl elog "$@" ;}
function enotify () { verb_lvl=$ntf_lvl elog "$@" ;}
function eok ()    { verb_lvl=$ntf_lvl elog "${colgrn}SUCCESS${colrst} - $@" ;}
function ewarn ()  { verb_lvl=$wrn_lvl elog "${colylw}WARNING${colrst} - $@" ;}
function einfo ()  { verb_lvl=$inf_lvl elog "${colblk}INFO${colrst} ---- $@" ;}
function edebug () { verb_lvl=$dbg_lvl elog "${colgrn}DEBUG${colrst} --- $@" ;}
function eerror () { verb_lvl=$err_lvl elog "${colred}ERROR${colrst} --- $@" ;}
function ecrit ()  { verb_lvl=$crt_lvl elog "${colpur}FATAL${colrst} --- $@" ;}
function edumpvar () { for var in $@ ; do edebug "$var=${!var}" ; done }
function elog() {
        if [ $verbosity -ge $verb_lvl ]; then
                datestring=$(date +"%Y-%m-%d %H:%M:%S")
                echo -e "$datestring - $@" 1>&2
        fi
}

pushd /releaser > /dev/null
set_vars "inputs.yaml"
main
popd > /dev/null
