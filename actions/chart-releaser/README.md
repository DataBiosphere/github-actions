# chart-releaser

A Github Action to automatically verison and release Helm charts

### Workflow
* Add this action to your repo
* Commit some changes
* Either push to master or open a PR
* On push (or merge) to `master`, the action will:
  * Get changed chart(s)
  * Bump chart version(s) with minor version unless the commit message contains `#major` or `#patch`
  * Tag version bump commit with new chart version(s)
  * Push version bump commit and tag(s)

### Usage
```Dockerfile
name: Release Charts
on:
  push:
    branches:
      - master
    paths-ignore:
      - 'charts/**/Chart.yaml'
      - 'README.md'
      - '.github/**'
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
        with:
          persist-credentials: false
          fetch-depth: '0'

      - name: Configure Git
        run: |
          git config user.name "$GITHUB_ACTOR"
          git config user.email "$GITHUB_ACTOR@users.noreply.github.com"

      - name: Run chart-releaser
        uses: docker://us-central1-docker.pkg.dev/dsp-artifact-registry/github-actions-public/action-releaser:latest
        env:
          GITHUB_TOKEN: "${{ secrets.CR_TOKEN }}"
```

#### Options

**Environment Variables**

* **GITHUB_TOKEN** ***(required)*** - Token for bumping versions and running chart-releaser
* **CHARTS_DIR** *(optional)* - Directory where chart subdirectories are located (default: `charts`)
* **VERSION_BUMP_LEVEL** *(optional)* - Which type of bump to use when none explicitly provided (default: `minor`)
* **VERBOSITY** *(optional)* - Verbosity level, with 1 being silent and 6 being debug (default: `5`)
* **GIT_BRANCH** *(optional)* - Branch to look for changes in (default: `master`)
* **GITHUB_OWNER** *(optional)* - GitHub repo owner (default: `BroadInstitute`)
* **GITHUB_REPO** *(optional)* - GitHub repo name (default: `terra-helm`)
