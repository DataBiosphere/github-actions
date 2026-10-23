# bumper

This is a fork of [github-tag-action](https://github.com/anothrNick/github-tag-action)
It has been extended for Terra workflow

A Github Action to automate version bumping.

### Usage

```Dockerfile
name: Bump version
on:
  push:
    branches:
    - main
    - 'hotfix**'
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
      with:
        token: ${{ secrets.GITHUB_TOKEN }}
    - name: Bump version and push tag
      uses: broadinstitute/github-actions/actions/bumper
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        WITH_V: true
        RELEASE_BRANCHES: main
        DEFAULT_BUMP: patch
        HOTFIX_BRANCHES: hotfix.*
        VERSION_FILE_PATH: build.gradle
        VERSION_LINE_MATCH: "^version \'.*\'"
```

#### Options

**Environment Variables**

* **GITHUB_TOKEN** ***(required)*** - Required for permission to tag the repo.
* **DEFAULT_BUMP** *(optional)* - Which type of bump to use when none explicitly provided (default: `minor`).
* **OVERRIDE_BUMP** *(optional)* - Overrides the default bump and any commit message bump
  indicator for which part of the semver to bump
* **WITH_V** *(optional)* - Tag version with `v` character.
* **RELEASE_BRANCHES** *(optional)* - Comma separated list of branches (bash reg exp accepted) that will generate the release tags. Other branches and pull-requests generate versions postfixed with the commit hash and do not generate any tag. Examples: `master` or `.*` or `release.*,hotfix.*,master` ...
* **HOTFIX_BRANCHES** *(optional)* - Comma separated list of branches (bash reg exp
  accepted) that will generate hotfix tags. Example: `hotfix.*`
* **SOURCE** *(optional)* - Operate on a relative path under $GITHUB_WORKSPACE.
* **DRY_RUN** *(optional)* - Determine the next version without tagging the branch. The workflow can use the outputs `new_tag` and `tag` in subsequent steps. Possible values are ```true``` and ```false``` (default).
* **INITIAL_VERSION** *(optional)* - Set initial version before bump. Default `0.0.0`.
* **TAG_CONTEXT** *(optional)* - Set the context of the previous tag. Possible values are `repo` (default) or `branch`.
* **VERSION_FILE_PATH** *(optional)* - If present, update the version number in that file
* **VERSION_LINE_MATCH** *(optional)* - If present, a grep regular expression to identify the line containing the version number in the VERSION_FILE_PATH.
* **VERSION_SUFFIX** *(optional)* - Suffix added to the version in the version file, such as, -SNAPSHOT
* **FORCE_WITHOUT_CHANGES** *(optional)* - Bump even if there are no changes from the previous version.

#### Outputs

* **new_tag** - The value of the newly created tag.
* **tag** - The value of the latest tag after running this action.
* **part** - The part of version which was bumped.

> ***Note:*** This action creates a [lightweight tag](https://developer.github.com/v3/git/refs/#create-a-reference).

### Bumping

The part of the semantic version to bump is controlled in this order:
 1. If in a hotfix branch (as defined by **HOTFIX_BRANCHES**), bump the value in the
 hotfix extension. If no extension is previously tagged, use `hotfix.0`.
 2. If **OVERRIDE_BUMP** is set, bump that part of the semvar: `major`, `minor`, or `patch`
 3. If any commit message includes `#major`, `#minor`, or `#patch`, that will trigger the respective version bump. If two or more are present, the highest-ranking one will take precedence.
 4. If **DEFAULT_BUMP** is set, it will bump that part of the semvar: `major`, `minor`, or
 `patch`. if **DEFAULT_BUMP** is `none`, then no version bump will be performed.
 5. The `patch` version is bumped

> ***Note:*** This action **will not** bump the tag if the `HEAD` commit has already been tagged.

### Workflow

#### Normal Flow

* Develop a code change in a working branch
* Make a PR from the working branch to `main`
* If you made changes that would merit a minor or major version bump, then before merging
the PR, set the commit message to include `#major` or `#minor`.
* Merging the PR triggers the action. It will
  * Get the latest tag
  * Bump the tag as described above
  * Write the tag to the specified version file
  * Push the tag to github

#### Hotfix Flow

* Prepare a hotfix branch:
  * Checkout the tag you need to hot fix into a branch named `hotfix/<something>`
  * `git push origin hotfix/<something>` to create the hotfix branch
  * `git checkout -b fixdevbranch` from the hotfix branch
  * Make the hot fix, commit, and push `fixdevbranch`
  * Make a PR to merge `fixdevbranch` into `hotfix/<something>`
  * When it is ready, merge.
* Merging the PR triggers the action. It will
  * Get the latest tag
  * Either append `-hotfix.0` or increment the existing hotfix number; e.g., `-hotfix.1`
  * Write the tag to the version file
  * Push the tag to github

### Credits

[fsaintjacques/semver-tool](https://github.com/fsaintjacques/semver-tool)

[github-tag-action](https://github.com/anothrNick/github-tag-action)
