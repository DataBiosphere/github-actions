#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -x

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
    repo_url=https://${cr_token}@github.com/${github_owner}/${github_repo}
    local repo_root=$(git rev-parse --show-toplevel)
    pushd "$repo_root" > /dev/null

    einfo "Discovering changed charts ..."
    local changed_charts=()
    readarray -t changed_charts <<< "$(lookup_changed_charts)"

    if [[ -n "${changed_charts[*]}" ]]; then
        rm -rf .cr-release-packages
        mkdir -p .cr-release-packages

        rm -rf .cr-index
        mkdir -p .cr-index

        local branch=$(git rev-parse --abbrev-ref HEAD)
        if [[ "$branch" == "$git_branch" ]]; then
            einfo "Bumping chart versions"
            for chart in "${changed_charts[@]}"; do
                if [[ -d "$chart" ]]; then
                    bump_chart_version "$chart"
                else
                    einfo "Chart '$chart' no longer exists in repo. Skipping it..."
                fi
            done

            git commit --message="bumping chart version(s)"
            git push "$repo_url" HEAD:${branch}
        fi

        for chart in "${changed_charts[@]}"; do
            if [[ -d "$chart" ]]; then
                package_chart "$chart"
            else
                einfo "Chart '$chart' no longer exists in repo. Skipping it..."
            fi
        done

        sleep 1
        release_charts
        sleep 1
        update_index
    else
        einfo "Nothing to do. No chart changes detected."
    fi

    popd > /dev/null
}

filter_charts() {
    while read chart; do
        [[ ! -d "$chart" ]] && continue
        local file="$chart/Chart.yaml"
        if [[ -f "$file" ]]; then
            echo $chart
        else
           einfo "WARNING: $file is missing, assuming that '$chart' is not a Helm chart. Skipping."
        fi
    done
}

lookup_changed_charts() {
    #look for changed files in the latest commit
    local changed_files
    if [[ $(jq '.pull_request' "$GITHUB_EVENT_PATH") != 'null' ]]; then
        pull_number=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
        changed_files=$(gh pr diff $pull_number | sed -n "s/^diff --git a\/\($charts_dir\/[^ ]*\).*/\1/p")
    else
        changed_files=$(git diff-tree --no-commit-id --name-only -r $(git rev-parse HEAD) -- $charts_dir)
    fi
    cut -d '/' -f '2' <<< "$changed_files" | uniq | filter_charts
}

bump_chart_version() {
    local chart="$1"
    local chart_yaml="$charts_dir/$chart/Chart.yaml"
    local current_version=$(yq read "$chart_yaml" version)
    local new_version=$(semver bump $version_bump_level $current_version)
    local msg="Bumping $chart from $current_version to $new_version"
    einfo "$msg"
    yq write "$chart_yaml" 'version' "$new_version"
    git add "$chart_yaml"
}

package_chart() {
    local chart="$1"
    local branch=$(git rev-parse --abbrev-ref HEAD)

    einfo "Packaging chart '$chart'..."

    if [[ "$branch" != "$git_branch" ]]; then
        version=$(yq read "$charts_dir/$chart/Chart.yaml" version)
        timestamp=$(date +%s)
        sha=$(git rev-parse --short=6 HEAD)
        if [[ $(jq '.pull_request' "$GITHUB_EVENT_PATH") != 'null' ]]; then
            pull_number=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
            rel_version="$version-$pull_number.$timestamp.$sha"
            einfo "In a PR. Releasing '$rel_version' version..."
        else
            rel_version="$version-$branch.$timestamp.$sha"
            einfo "Not on $git_branch branch. Releasing '$rel_version' version..."
        fi

        helm package "$chart" --version "$rel_version" --destination .cr-release-packages --dependency-update
    else
        helm package "$chart" --destination .cr-release-packages --dependency-update
    fi
}

release_charts() {
    einfo 'Releasing charts...'
    cr upload -o "$github_owner" -r "$github_repo" -t "$cr_token"
}

update_index() {
    einfo 'Updating charts repo index...'

    cr index -o "$github_owner" -r "$github_repo" -c "$charts_repo_url" -t "$cr_token"

    gh_pages_worktree=$(mktemp -d)

    git worktree add "$gh_pages_worktree" gh-pages

    cp --force .cr-index/index.yaml "$gh_pages_worktree/index.yaml"

    pushd "$gh_pages_worktree" > /dev/null

    git add index.yaml
    git commit --message="Update index.yaml" --signoff

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
popd > /dev/null

main
