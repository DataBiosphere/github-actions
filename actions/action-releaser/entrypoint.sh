#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

main() {
    git_init

    git clone --single-branch --branch "$INPUT_GIT_BRANCH" "https://$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY"
    local repo_name=$(echo "$GITHUB_REPOSITORY" | awk -F '/' '{print $2}')
    pushd "$repo_name" > /dev/null

    einfo "Discovering changed actions ..."
    local changed_actions=()
    readarray -t changed_actions <<< "$(lookup_changed_actions)"

    if [[ -n "${changed_actions[*]}" ]]; then
        local changes=false
        for action in "${changed_actions[@]}"; do
            if [[ -d "$INPUT_ACTIONS_DIR/$action" ]]; then
                local current_tag=$(lookup_latest_tag $action)
                if [[ "$current_tag" == '' ]]; then
                    local new_semver="0.0.0"
                else
                    local current_semver=${current_tag#"$action-"}
                    local new_semver=$(semver bump $INPUT_VERSION_BUMP_LEVEL $current_semver)
                fi
                local dockerfile="$INPUT_ACTIONS_DIR/$action/Dockerfile"
                # Only bump image version on containerized actions
                if [[ -f "$dockerfile" ]]; then
                    set_action_version "$action" "$new_semver"
                    changes=true
                fi
                tag_action "$action" "$new_semver"
            else
                ewarn "Action '$action' no longer exists in repo. Skipping it..."
            fi
        done
        # Only commit if there are file changes
        if $changes; then
            push_changes
        else
            einfo "No action.yml updates, not pushing changes"
        fi
        push_tags
    else
        einfo "Nothing to do. No action changes detected."
    fi

    popd > /dev/null
}

git_init() {
    git config --global user.name "$GITHUB_ACTOR"
    git config --global user.email "$GITHUB_ACTOR@noreply.github.com"
}

lookup_latest_tag() {
    local action="$1"
    git fetch --tags > /dev/null 2>&1

    edebug "Looking for latest tag for $action"
    git for-each-ref --sort=-taggerdate --count=1 --format '%(refname:lstrip=-1)' "refs/tags/$action-*"
}

filter_actions() {
    while read action; do
        [[ ! -d "$INPUT_ACTIONS_DIR/$action" ]] && continue
        local action_yml="$INPUT_ACTIONS_DIR/$action/action.yml"
        if [[ -f "$action_yml" ]]; then
            echo "$action"
        else
            ewarn "$action_yml is missing. Skipping."
        fi
    done
}

lookup_changed_actions() {
    #look for changed files in the latest commit
    local changed_files
    changed_files=$(git diff-tree --no-commit-id --name-only -r "$(git rev-parse HEAD)" -- $INPUT_ACTIONS_DIR)
    cut -d '/' -f '2' <<< "$changed_files" | uniq | filter_actions
}

set_action_version() {
    local action="$1"
    local version="$2"

    local msg="Updating action.yml of $action to point to the '$version' tag"
    einfo "$msg"
    git add -u
    git commit -am "$msg"
    yq w -i "actions/$action/action.yml" 'runs.image' "$INPUT_DOCKER_REPO/$action:$version"
}

tag_action() {
    local action="$1"
    local version="$2"
    local tag="$action-$version"

    einfo "Creating tag '$tag'"
    git tag "$tag"
}

push_changes() {
    einfo 'Pushing changes...'
    git push "https://$GITHUB_ACTOR:$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY"
}

push_tags() {
    einfo 'Pushing tags...'
    git push --tags "https://$GITHUB_ACTOR:$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY"
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
        if [ $INPUT_VERBOSITY -ge $verb_lvl ]; then
                datestring=$(date +"%Y-%m-%d %H:%M:%S")
                echo -e "$datestring - $@" 1>&2
        fi
}

pushd /releaser > /dev/null
main
popd > /dev/null
