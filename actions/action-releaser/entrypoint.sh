#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

main() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel)

    echo "Discovering changed actions ..."
    local changed_actions=()
    readarray -t changed_actions <<< "$(lookup_changed_actions)"

    if [[ -n "${changed_actions[*]}" ]]; then
        for action in "${changed_actions[@]}"; do
            if [[ -d "$action" ]]; then
                tag_action "$action"
            else
                echo "Action '$action' no longer exists in repo. Skipping it..."
            fi
        done
    else
        echo "Nothing to do. No action changes detected."
    fi
}

lookup_latest_tag() {
    local chart="$1"
    git fetch --tags > /dev/null 2>&1

    if ! git describe --tags --abbrev=0 2> /dev/null; then
        git rev-list --max-parents=0 --first-parent HEAD
    fi

    case "$tag_context" in
            *repo*) tag=$(git for-each-ref --sort=-v:refname --count=1 --format '%(refname)' refs/tags/[0-9]*.[0-9]*.[0-9]* refs/tags/v[0-9]*.[0-9]*.[0-9]* | cut -d / -f 3-);;
            *branch*) tag=$(git describe --tags --match "*[v0-9].*[0-9\.]" --abbrev=0);;
            * ) echo "Unrecognised context"; exit 1;;
    esac

    # get current commit hash for tag
    tag_commit=$(git rev-list -n 1 $tag)

    # get current commit hash
    commit=$(git rev-parse HEAD)
}

filter_charts() {
    while read chart; do
        [[ ! -d "$chart" ]] && continue
        local file="$chart/Chart.yaml"
        if [[ -f "$file" ]]; then
            echo $chart
        else
           echo "WARNING: $file is missing, assuming that '$chart' is not a Helm chart. Skipping." 1>&2
        fi
    done
}

lookup_changed_charts() {
    #look up for changed files in the latest commit
    local changed_files
    changed_files=$(git diff-tree --no-commit-id --name-only -r $(git rev-parse HEAD) -- $charts_dir)

    local fields
    if [[ "$charts_dir" == '.' ]]; then
        fields='1'
    else
        fields='1,2'
    fi

    cut -d '/' -f "$fields" <<< "$changed_files" | uniq | filter_charts
}

package_chart() {
    local chart="$1"

    echo "Packaging chart '$chart'..."

    branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$branch" != 'master' ]]; then
        version=$(helm show chart $chart | sed -ne 's/^version: //p')
        timestamp=$(date +%s)
        sha=$(git rev-parse --short=6 HEAD)
        if echo $GITHUB_REF | grep 'refs/pull/'; then
            pull_number=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
            rel_version="$version-$pull_number.$timestamp.$sha"
            echo "In a PR. Releasing '$rel_version' version..."
        else
            rel_version="$version-$branch.$timestamp.$sha"
            echo "Not on master branch. Releasing '$rel_version' version..."
        fi

        helm package "$chart" --version "$rel_version" --destination .cr-release-packages --dependency-update
    else
        helm package "$chart" --destination .cr-release-packages --dependency-update
    fi
}

release_charts() {
    echo 'Releasing charts...'

        cr upload -o "$owner" -r "$repo" -t "$CR_TOKEN"

}

update_index() {
    echo 'Updating charts repo index...'

    set -x

    cr index -o "$owner" -r "$repo" -c "$charts_repo_url" -t "$CR_TOKEN"

    cp --force .cr-index/index.yaml "$gh_pages_worktree/index.yaml"

    pushd "$gh_pages_worktree" > /dev/null

    git add index.yaml
    git commit --message="Update index.yaml" --signoff

    local repo_url=https://x-access-token:${CR_TOKEN}@github.com/${owner}/${repo}
    git push "$repo_url" HEAD:gh-pages

    popd > /dev/null
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
function eok ()    { verb_lvl=$ntf_lvl elog "SUCCESS - $@" ;}
function ewarn ()  { verb_lvl=$wrn_lvl elog "${colylw}WARNING${colrst} - $@" ;}
function einfo ()  { verb_lvl=$inf_lvl elog "${colwht}INFO${colrst} ---- $@" ;}
function edebug () { verb_lvl=$dbg_lvl elog "${colgrn}DEBUG${colrst} --- $@" ;}
function eerror () { verb_lvl=$err_lvl elog "${colred}ERROR${colrst} --- $@" ;}
function ecrit ()  { verb_lvl=$crt_lvl elog "${colpur}FATAL${colrst} --- $@" ;}
function edumpvar () { for var in $@ ; do edebug "$var=${!var}" ; done }
function elog() {
        if [ $verbosity -ge $verb_lvl ]; then
                datestring=$(date +"%Y-%m-%d %H:%M:%S")
                echo -e "$datestring - $@"
        fi
}

pushd /releaser > /dev/null
set_vars "inputs.yaml"
main
popd > /dev/null
