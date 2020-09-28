# action-releaser

A Github Action to automatically bump and tag master, on merge, with new versions for any changed GitHub actions defined in a repository.

### Usage

```Dockerfile
name: Release Actions
on:
  push:
    branches:
      - master
    paths:
      - 'actions/**'
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
    - name: Bump version and push tags
      uses: databiosphere/github-actions/actions/action-releaser@master
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### Options

**Environment Variables**

* **GITHUB_TOKEN** ***(required)*** - Required for permission to tag the repo
* **ACTIONS_DIR** *(optional)* - Directory where action subdirectories are located (default: `actions`)
* **VERSION_BUMP_LEVEL** *(optional)* - Which type of bump to use when none explicitly provided (default: `minor`)
* **VERBOSITY** *(optional)* - Verbosity level, with 1 being silent and 6 being debug (default: `5`)
* **GIT_BRANCH** *(optional)* - Branch to look for changes in (default: `master`)
* **GIT_USER** *(optional)* - User name to initialize Git with (default: `broadbot`)
* **GIT_EMAIL** *(optional)* - User email to initialize Git with (default: `broadbot@broadinstitute.org`)
* **GITHUB_OWNER** *(optional)* - GitHub repo owner (default: `DataBiosphere`)
* **GITHUB_REPO** *(optional)* - GitHub repo name (default: `github-actions`)

### Workflow

* Add this action to your repo
* Commit some changes
* Either push to master or open a PR
* On push (or merge) to `master`, the action will:
  * Find any actions that were changed in the last commit
  * For each of those actions, find their latest version tag and bump the version according to `VERSION_BUMP_LEVEL`
  * Push tags to GitHub
