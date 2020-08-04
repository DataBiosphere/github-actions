#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")

main() {
    owner=$(cut -d '/' -f 1 <<< "$GITHUB_REPOSITORY")
    repo=$(cut -d '/' -f 2 <<< "$GITHUB_REPOSITORY")
    args=(--owner "$owner" --repo "$repo")
    args+=(--actions-dir "${INPUT_ACTIONS_DIR?Input 'actions_dir' is required}")

    "$SCRIPT_DIR/cr.sh" "${args[@]}"
}

main
