#!/bin/bash

# config
default_semvar_bump=${DEFAULT_BUMP:-patch}
override_semvar_bump=${OVERRIDE_BUMP}
with_v=${WITH_V:-false}
release_branches=${RELEASE_BRANCHES:-main}
hotfix_branches=${HOTFIX_BRANCHES:-hotfix.*}
source=${SOURCE:-.}
dryrun=${DRY_RUN:-false}
initial_version=${INITIAL_VERSION:-0.0.0}
tag_context=${TAG_CONTEXT:-repo}
version_file_path=${VERSION_FILE_PATH}
version_line_match=${VERSION_LINE_MATCH}
version_suffix=${VERSION_SUFFIX}
hotfix_version=${HOTFIX_VERSION}

cd ${GITHUB_WORKSPACE}/${source}
git config --global --add safe.directory /github/workspace
current_branch=$(git rev-parse --abbrev-ref HEAD)

hotfix_release="false"
IFS=',' read -ra branch <<< "$hotfix_branches"
for b in "${branch[@]}"; do
    echo "Is $b a match for ${current_branch}"
    if [[ "${current_branch}" =~ $b ]]
    then
        hotfix_release="true"
    fi
done
echo "hotfix_release = $hotfix_release"

# By definition, if it is a hotfix release, it is not pre_release
if $hotfix_release; then
    pre_release="false"
else
    pre_release="true"
    IFS=',' read -ra branch <<< "$release_branches"
    for b in "${branch[@]}"; do
        echo "Is $b a match for ${current_branch}"
        if [[ "${current_branch}" =~ $b ]]
        then
            pre_release="false"
        fi
    done
fi    
echo "pre_release = $pre_release"

# fetch tags
git fetch --tags

# get latest tag that looks like a semver (with or without v, using with_v)
if $with_v; then
  tag_pattern="refs/tags/v[0-9]*.[0-9]*.[0-9]*"
else
  tag_pattern="refs/tags/[0-9]*.[0-9]*.[0-9]*"
fi
case "$tag_context" in
    *repo*) tag=$(git for-each-ref --sort=-v:refname --count=1 --format '%(refname)' "$tag_pattern" | cut -d / -f 3-);;
    *branch*) tag=$(git describe --tags --match "*[v0-9].*[0-9\.]" --abbrev=0);;
    * ) echo "Unrecognised context"; exit 1;;
esac

# get current commit hash for tag
# on the initial use, this shows usage, because $tag is empty. The logic below still works.
tag_commit=$(git rev-list -n 1 $tag)

# get current commit hash
commit=$(git rev-parse HEAD)

if [ "$tag_commit" == "$commit" ]; then
    echo "No new commits since previous tag. Skipping..."
    echo ::set-output name=tag::$tag
    exit 0
fi

# if there are none, start tags at INITIAL_VERSION which defaults to 0.0.0
if [ -z "$tag" ]
then
    log=$(git log --pretty='%B')
    tag="$initial_version"
else
    log=$(git log $tag..HEAD --pretty='%B')
fi

echo $log

HOTFIX_REGEX="^hotfix\\.(0|[1-9][0-9]*)$"
if $hotfix_release; then
    # For hotfix release, we compute the hotfix string and do not bump any fields in the version number part
    if [ -n "$hotfix_version" ]; then
        # Specific hotfix version specified
        hotfix_string="hotfix.${hotfix_version}"
    else
        # Compute the hotfix string by trying to read the version from the prerel
        # If it isn't there or isn't in our hotfix format, then we use hotfix.0
        hotfix_string="hotfix.0"
        prerel=$(semver get prerel $tag)
        echo "get prerel is '$prerel'"
        if [ -n "$prerel" ]; then
            # We have a prerel. See if it is a proper hotfix
            if [[ "$prerel" =~ $HOTFIX_REGEX ]]; then
                hotfix_incr="$((${BASH_REMATCH[1]} + 1))"
                hotfix_string="hotfix.$hotfix_incr"
            else
                echo "prerel did not match hotfix regex"
            fi
        fi
    fi
    new=$(semver bump prerel $hotfix_string $tag)
    part="hotfix"
else           
    # For non-hotfix, we compute the new version
    # If there is an override for what part to bump, use that. If there is a #xyz in the log message, use that.
    # Othewise, use the default part.
    if [ -n "$override_semvar_bump" ]; then
        part=$override_semvar_bump
    else
        # No override, check the commit message.
        # Failing that, use the default.
        case "$log" in
            *#major* ) part="major";;
            *#minor* ) part="minor";;
            *#patch* ) part="patch";;
            * )
                if [ "$default_semvar_bump" == "none" ]; then
                    echo "Default bump was set to none. Skipping..."
                    exit 0
                else
                    part="${default_semvar_bump}"
                fi
        esac
    fi
    new=$(semver bump $part $tag)
fi

echo "Updated semver part $part"

# did we get a new tag?
if [ ! -z "$new" ]
then
    # prefix with 'v'
    if $with_v
    then
	new="v$new"
    fi
    
    if $pre_release
    then
	new="$new-${commit:0:7}"
    fi
fi

echo "New tag is $new"

# set outputs
echo ::set-output name=new_tag::$new
echo ::set-output name=part::$part

# use dry run to determine the next tag
if $dryrun
then
    echo ::set-output name=tag::$tag
    exit 0
fi 

echo ::set-output name=tag::$new


if $pre_release
then
    echo "This branch is not a release branch. Skipping the tag creation."
    exit 0
fi

# bump the version in the file located at ${VERSION_FILE_PATH}
# expects that there is a line that matches the regular expression: ${VERSION_LINE_MATCH}
# we replaced that line with one that has the updated version, possibly including the version suffix
if [ -z "$version_file_path" ] || [ -z "$version_line_match" ]; then
    echo "Skipping bump of version file."
else
    if [ -z "$version_suffix" ]; then
        version_new=$new
    else
        version_new=${new}-${version_suffix}
    fi
    version_line=$(cat $version_file_path | grep -e "${version_line_match}")
    if [ -z "$version_line" ]; then
        echo "No version line found; no bump of version file."
    else
        new_line=$(echo "$version_line" | sed -E -e "s/(.*)([0-9]+\.[0-9]+\.[0-9]+-?[a-zA-Z0-9]*)(.*)/\1${version_new}\3/")
        sed -E -i.bak -e "s/${version_line}/${new_line}/" $version_file_path
    fi
    git config --global user.email "robot@terra.team"
    git config --global user.name "bumptagbot"
    git add $version_file_path
    git commit -m "bump ${new}"
    git push origin $current_branch
    commit=$(git rev-parse HEAD)
fi

# push new tag ref to github
dt=$(date '+%Y-%m-%dT%H:%M:%SZ')
full_name=$GITHUB_REPOSITORY
git_refs_url=$(jq .repository.git_refs_url $GITHUB_EVENT_PATH | tr -d '"' | sed 's/{\/sha}//g')

echo "$dt: **pushing tag $new to repo $full_name"

curl -s -X POST $git_refs_url \
-H "Authorization: token $GITHUB_TOKEN" \
-d @- << EOF

{
  "ref": "refs/tags/$new",
  "sha": "$commit"
}
EOF
