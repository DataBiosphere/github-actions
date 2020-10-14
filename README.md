# Data Biosphere GitHub Actions
This repository is meant to house containerized Data Biosphere-adjacent GitHub actions. Having them all live together in this repo makes it easier to maintain a consistent set of standards and CI pipelines for them.

## Build process
The [action-releaser action](https://github.com/DataBiosphere/github-actions/tree/master/actions/action-releaser), also hosted in this repository, is used in the [release workflow](https://github.com/DataBiosphere/github-actions/blob/master/.github/workflows/release.yml) to bump the version tags of any actions when changes to them are merged to master.
A [Google Cloud Build trigger](https://console.cloud.google.com/cloud-build/triggers/edit/5414cabd-9785-4bb8-9561-669d2a8264c8?project=dsp-artifact-registry) is set up to look for those tags and build the action containers as defined in the [`cloudbuild.yaml` config file](https://github.com/DataBiosphere/github-actions/blob/master/cloudbuild.yaml).
The build publishes the images to the public github actions repo, tagged with the versions, where they can be [pulled by GH action workflows](#point-to-image).

## Using actions defined in this repo
The actions defined in this repo can be used by either pointing to their definitions in this repo, or to the corresponding images & tags in the public container repo.

### Point to image
Pointing your workflow to in image will result in faster workflow execution times, since the image does not need to be built from its definition every time. However, currently this is only possible to do for versions of the actions that have been merged to master and tagged/built as per the above build process. If a version of an action from a branch needs to be referenced, such as when testing changes, refer instead to the [pointing to the code](#point-to-code) section below.

Examples of GH action workflow syntax referencing an image from the public Google Artifact repo:

Grab the latest image of the action-releaser action:
```
steps:
- name: Bump version and push tags
  uses: docker://us-central1-docker.pkg.dev/dsp-artifact-registry/github-actions-public/action-releaser:latest
```

Grab a specific version of the action-releaser action:
```
uses: docker://us-central1-docker.pkg.dev/dsp-artifact-registry/github-actions-public/action-releaser:0.0.0
```

### Point to code
To point a workflow to the definition of the action in this repository, use the below syntax. Note that this will result in the image being re-built every time the workflow runs. GitHub has some caching implemented but currently this is still much slower than pulling the image from the artifact repo.

Build the action from the latest code in master:
```
uses: databiosphere/github-actions/actions/action-releaser@master
```

Build the action from the latest code in the foo branch:
```
uses: databiosphere/github-actions/actions/action-releaser@foo
```

Build the action from a specific version tag:
```
uses: databiosphere/github-actions/actions/action-releaser@action-releaser-0.0.0
```

## Adding new actions
Adding actions is fairly straightforward
- Create a new subdirectory for your action in the actions folder
- This repository is only for containerized actions, so be sure to include a Dockerfile and follow other [GitHub actions best practices](https://docs.dsp-devops.broadinstitute.org/best-practices-guides/github-actions)
- Open a PR with your changes. Mention it in the #dsp-devops-champions Slack channel if you need someone to taka a look ASAP.

Once merged, your new action should get automatically tagged, built, and pushed to the public Google Artifact repo, where it can be pulled from by GH action workflows.
