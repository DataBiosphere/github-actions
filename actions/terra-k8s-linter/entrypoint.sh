#!/bin/sh
set -x

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <manifests_dir> $1 <custom_policies_dir> $2 <ignored_policies_dir> " &2
  exit 1
fi

echo "test5"
pwd

policy_args=""

MANIFESTS_DIR="$1"
CUSTOM_POLICIES_DIR="$2"
IGNORE_DEFAULT_POLICY="$3"

# if [ $IGNORE_DEFAULT_POLICY ]
# then
#   cmd+=" -i /policy"
# fi

# if [ -n $CUSTOM_POLICIES_DIR ]
# then
#   if [ ${#policy_args} -gt 0 ]
#   then
#     policy_args+=",$CUSTOM_POLICIES_DIR"
#   else
#     policy_args+="-p $CUSTOM_POLICIES_DIR"
#   fi
# fi

conftest test "${MANIFESTS_DIR}"
