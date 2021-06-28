#!/bin/sh

# RUN DEFAULT POLICIES AND CUSTOM policies
# -P /POLICY,/CUSTOM_POLICIES_DIR
# RUN CUSTOM POLICIES ONLY
#  -P /CUSTOM_POLICIES_DIR
# RUN DEFAULT POLICIESE ONLY
#  -P /POLICY
# RUN CUSTOM POLICIES BUT DONT PROVIDE DIRECTORY
# THROW ERROR

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <manifests_dir> $1 <custom_policies_dir> $2 <ignored_policies_dir> " &2
  exit 1
fi


policy_dirs=""

MANIFESTS_DIR="$1"
CUSTOM_POLICIES_DIR="$2"
IGNORE_DEFAULT_POLICY="$3"

if [[ "$IGNORE_DEFAULT_POLICY" == "true" ]]; then
  if [[ -z "$CUSTOM_POLICIES_DIR" ]]; then
    echo "Please provide directory where custom policies reside." >&2
    exit 1
  else
    policy_dirs="${CUSTOM_POLICIES_DIR}"
  fi
else
  if [[ -z "$CUSTOM_POLICIES_DIR" ]]; then
    policy_dirs="/policy"
  else
    policy_dirs="/policy,${CUSTOM_POLICIES_DIR}"
  fi
fi

# Run policies against manifests in directory except those associated with daterepo
# Temporaily exclude buffer until bug dealing with manifests are addressed
conftest test "${MANIFESTS_DIR}" -p "${policy_dirs}" --ignore="(^.*datarepo.*|${policy_dirs})"
