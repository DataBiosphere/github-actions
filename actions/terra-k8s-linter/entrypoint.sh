#!/bin/sh

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <manifests_dir>" >&2
  exit 1
fi

MANIFESTS_DIR="$1"

conftest test "$MANIFESTS_DIR" -p /policy
