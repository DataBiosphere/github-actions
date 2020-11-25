# Data Biosphere GitHub Actions
This repository is meant to house Data Biosphere-adjacent GitHub actions. Having them all live together in this repo makes it easier to maintain a consistent set of standards and CI pipelines for them.

## Build process
The [action-releaser action](https://github.com/DataBiosphere/github-actions/tree/master/actions/action-releaser), also hosted in this repository, is used in the [release workflow](https://github.com/DataBiosphere/github-actions/blob/master/.github/workflows/release.yml) to bump the version tags of any actions when changes to them are merged to master.
A [Google Cloud Build trigger](https://console.cloud.google.com/cloud-build/triggers/edit/5414cabd-9785-4bb8-9561-669d2a8264c8?project=dsp-artifact-registry) is set up to look for those tags and build the action containers as defined in the [`cloudbuild.yaml` config file](https://github.com/DataBiosphere/github-actions/blob/master/cloudbuild.yaml).
The build publishes the images to the public github actions repo, tagged with the versions, where they can be [pulled by GH action workflows](#point-to-tag).

## Using actions defined in this repo
The actions defined in this repo can be used by pointing to their folder and tag/branch in this repo.

### Point to tag
Pointing your workflow to a tag corresponding to a version of an action that has been released from the master branch is the recommended way to use these actions. This will lock your workflow to a specific version of the action and result in fast build times, since every version-tagged commit in turn points to a pre-built image for that action.
```
uses: databiosphere/github-actions/actions/locker@locker-0.7.0
```

### Point to a branch
#### master
If running the latest version of the action is more important than stability, pointing to the `master` branch will make your workflow pull the latest released image for an action:
```
uses: databiosphere/github-actions/actions/locker@master
```
#### Other branches
Pointing to a branch is also useful when testing changes to an action or developing a new action:
```
uses: databiosphere/github-actions/actions/locker@foo-test-action
```
For this use case, make sure to also update the `action.yml` for the action under development to point to its local definition instead of an official image:
```
runs:
  using: "docker"
  image: "Dockerfile"
```

## Adding new actions
Adding actions is fairly straightforward
- Create a new subdirectory for your action in the actions folder
- Ideally containerize your action, include a Dockerfile and follow other [GitHub actions best practices](https://docs.dsp-devops.broadinstitute.org/best-practices-guides/github-actions)
- Open a PR with your changes. Mention it in the #dsp-devops-champions Slack channel if you need someone to take a look ASAP.

Once merged, your new action should get automatically version-tagged, and if it is containerized also built and pushed to the public Google Artifact repo.
