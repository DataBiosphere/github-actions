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
    repo_url=https://x-access-token:${github_token}@github.com/${github_owner}/${github_repo}
    charts_repo_url=https://${github_owner}.github.io/${github_repo}

    setup

    local repo_root=$(git rev-parse --show-toplevel)
    pushd "$repo_root" > /dev/null
    edebug "Working in $repo_root"

    einfo "Discovering changed charts ..."
    local changed_charts=()
    readarray -t changed_charts <<< "$(lookup_changed_charts)"
    edumpvar changed_charts

    if [[ -n "${changed_charts[*]}" ]]; then
        edebug "Configuring chart releaser folders"
        rm -rf .cr-release-packages
        mkdir -p .cr-release-packages
        rm -rf .cr-index
        mkdir -p .cr-index

        local branch=$(git rev-parse --abbrev-ref HEAD)
        edumpvar branch
        if [[ "$branch" == "$git_branch" ]]; then
            einfo "Bumping chart versions"
            for chart in "${changed_charts[@]}"; do
                if [[ -d "$charts_dir/$chart" ]]; then
                    bump_chart_version "$chart"
                else
                    einfo "Chart '$chart' no longer exists in repo. Skipping it..."
                fi
            done

            git commit --message="bumping chart version(s)"
            git pull "$repo_url" ${branch}
            git push "$repo_url" ${branch}

            eok 'Chart version(s) bumped and pushed'
        fi

        for chart in "${changed_charts[@]}"; do
            if [[ -d "$charts_dir/$chart" ]]; then
                package_chart "$chart"
            else
                einfo "Chart '$chart' no longer exists in repo. Skipping it..."
            fi
        done

        sleep 1
        release_charts
        sleep 3
        update_index
    else
        einfo "Nothing to do. No chart changes detected."
    fi

    popd > /dev/null

    eok 'All done!'
}

lookup_changed_charts() {
    # Look for changed files in the latest commit or PR
    local changed_files
    if [[ $(jq '.pull_request' "$GITHUB_EVENT_PATH") != 'null' ]]; then
        einfo "In a PR. Looking for changed files in the whole PR"
        pull_number=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
        changed_files=$(curl -s https://api.github.com/repos/$github_owner/$github_repo/pulls/$pull_number/files | jq -r '.[].filename' | grep "^$charts_dir/")
    else
        einfo "Not in a PR. Looking for changed files in latest commit"
        changed_files=$(git diff-tree --no-commit-id --name-only -r $(git rev-parse HEAD) -- $charts_dir)
    fi
    edumpvar changed_files
    cut -d '/' -f '2' <<< "$changed_files" | uniq
}

bump_chart_version() {
    local chart="$1"
    local chart_yaml="$charts_dir/$chart/Chart.yaml"
    local current_version=$(yq read "$chart_yaml" version)

    # Check current commit message for version bump level override
    local last_msg=$(git log -1 --pretty='%B')
    edumpvar last_msg
    case "$last_msg" in
        *#major* ) version_bump_level="major";;
        *#minor* ) version_bump_level="minor";;
        *#patch* ) version_bump_level="patch";;
        * ) einfo "No bump level override found.";;
    esac

    local new_version=$(semver bump $version_bump_level $current_version)
    local msg="Bumping $chart from $current_version to $new_version"

    einfo "$msg"

    yq write -i "$chart_yaml" 'version' "$new_version"
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
        edumpvar version timestamp sha
        if [[ $(jq '.pull_request' "$GITHUB_EVENT_PATH") != 'null' ]]; then
            pull_number=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
            rel_version="$version-$pull_number.$timestamp.$sha"
            einfo "In a PR. Releasing '$rel_version' version..."
        else
            rel_version="$version-$branch.$timestamp.$sha"
            einfo "Not on $git_branch branch. Releasing '$rel_version' version..."
        fi

        helm package "$charts_dir/$chart" --version "$rel_version" --destination .cr-release-packages --dependency-update
    else
        helm package "$charts_dir/$chart" --destination .cr-release-packages --dependency-update
    fi

    eok "Chart '$chart' packaged"
}

release_charts() {
    release_charts_cr || return $?
    release_charts_gcs
}

release_charts_cr() {
    einfo 'Releasing charts with chart-releaser...'
    cr upload -o "$github_owner" -r "$github_repo" -t "$github_token" -c "$(git rev-parse HEAD)"
    eok 'Charts released'
}

release_charts_gcs() {
    if [[ "$gcs_publishing_enabled" != "true" ]]; then
        einfo "GCS publishing disabled, won't upload charts to GCS bucket"
        return 0
    fi

    einfo "Uploading new charts to GCS bucket: $( ls .cr-release-packages/*.tgz )"
    # Allow charts tgz files to be cached for up to 5 minutes
    gsutil -h "Cache-Control: public, max-age=300" \
      cp .cr-release-packages/*.tgz "gs://${gcs_bucket}/charts" || return $?

    eok 'Charts released'
}

update_index() {
    update_index_cr || return $?
    update_index_gcs
}

update_index_cr() {
    einfo 'Updating charts repo index with chart-releaser...'

    cr index -o "$github_owner" -r "$github_repo" -c "$charts_repo_url" -t "$github_token"
    gh_pages_worktree=$(mktemp -d)
    git worktree add "$gh_pages_worktree" gh-pages
    cp --force .cr-index/index.yaml "$gh_pages_worktree/index.yaml"

    pushd "$gh_pages_worktree" > /dev/null

    git add index.yaml
    git commit --message="Update index.yaml" --signoff
    git push "$repo_url" HEAD:gh-pages

    popd > /dev/null

    eok 'Index updated'
}

update_index_gcs() {
    if [[ "$gcs_publishing_enabled" != "true" ]]; then
        einfo "GCS publishing disabled, won't update index.yaml in ${gcs_bucket} bucket"
        return 0
    fi

    index_dir=".gcs-index-tmp"
    mkdir -p "${index_dir}/charts" || return $?

    einfo "Copying index.yaml from ${gcs_bucket} bucket to ${index_dir}"
    gsutil cp "gs://${gcs_bucket}/index.yaml" \
      "${index_dir}/index.original.yaml" || return $?

    einfo "Generating updated index.yaml"
    cp .cr-release-packages/*.tgz "${index_dir}/charts" || return $?
    helm repo index \
      "${index_dir}" \
      --merge "${index_dir}/index.original.yaml" \
      --url="https://${gcs_bucket}.storage.googleapis.com/" || return $?

    # Set Cache-Control to no-cache so that Helm always pulls down the latest copy of the index.yaml file
    einfo "Uploading index.yaml to ${gcs_bucket} bucket"
    gsutil -h "Cache-Control: no-cache" \
      cp "${index_dir}/index.yaml" "gs://${gcs_bucket}/index.yaml" || return $?

    einfo "Cleaning up ${index_dir}"
    rm -rf "${index_dir}" || return $?

    eok 'Index updated'
}

setup() {
    setup_gcs
}

setup_gcs() {
    if [[ "$gcs_publishing_enabled" != "true" ]]; then
        einfo "GCS publishing disabled, won't set up up GCP auth"
        return 0
    fi

    einfo 'Authenticating to GCP...'
    # https://cloud.google.com/sdk/gcloud/reference/auth/activate-service-account
    gcloud auth activate-service-account --key-file="${gcs_sa_key_file}"
    eok 'Authed to GCP'
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
popd > /dev/null

main
