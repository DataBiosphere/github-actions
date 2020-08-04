#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

: "${GH_TOKEN:?Environment variable GH_TOKEN must be set}"

show_help() {
cat << EOF
Usage: $(basename "$0") <options>

    -h, --help               Display help
    -d, --actions-dir        The actions directory (defaut: actions)
    -o, --owner              The repo owner
    -r, --repo               The repo name
EOF
}

main() {
    local actions_dir=actions
    local owner=
    local repo=

    parse_command_line "$@"

    echo "$repo"
    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    pushd "$repo_root" > /dev/null

    echo "Discovering changed actions ..."
    local changed_actions=()
    readarray -t changed_actions <<< "$(lookup_changed_actions)"

    if [[ -n "${changed_actions[*]}" ]]; then

        for action in "${changed_actions[@]}"; do
            if [[ -d "$chart" ]]; then
                build_action "$action"
            else
                echo "Action '$action' no longer exists in repo. Skipping it..."
            fi
        done

        sleep 1
        release_actions

    else
        echo "Nothing to do. No action changes detected."
    fi

    popd > /dev/null
}

parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            -d|--actions-dir)
                if [[ -n "${2:-}" ]]; then
                    actions_dir="$2"
                    shift
                else
                    echo "ERROR: '-d|--actions-dir' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -o|--owner)
                if [[ -n "${2:-}" ]]; then
                    owner="$2"
                    shift
                else
                    echo "ERROR: '--owner' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -r|--repo)
                if [[ -n "${2:-}" ]]; then
                    repo="$2"
                    shift
                else
                    echo "ERROR: '--repo' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            *)
                break
                ;;
        esac

        shift
    done

    if [[ -z "$owner" ]]; then
        echo "ERROR: '-o|--owner' is required." >&2
        show_help
        exit 1
    fi

    if [[ -z "$repo" ]]; then
        echo "ERROR: '-r|--repo' is required." >&2
        show_help
        exit 1
    fi
}

lookup_latest_tag() {
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

main "$@"
