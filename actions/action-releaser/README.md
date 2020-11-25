# action-releaser

A Github Action that enables CI of multiple GH Actions in a repository:
- Bumps version tags on the main branch on merge for any changed GitHub actions.
- Bumps container version tags in the action.yml for any changed containerized actions

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
    - name: Bump versions and tags
      uses: databiosphere/github-actions/actions/action-releaser@master
```

#### Inputs
| Name | Default | Description|
| ---- | ------- | ---------- |
| `actions_dir` | actions | Directory where action subdirectories are located |
| `version_bump_level` | minor | Level of version (major/minor/patch) to bump |
| `verbosity` | '5' | Verbosity level, with 1 being silent and 6 being debug |
| `git_branch` | master | Git branch to use |
| `docker_repo` | docker://us-central1-docker.pkg.dev/dsp-artifact-registry/github-actions-public | Docker container repository |

#### Expected Environment Variables

This action expects the following environment variables to be set. Github workflows should pass them automatically, but if this container is run outside of the GH Actions context, they will need to be passed in manually.
- GITHUB_TOKEN
- GITHUB_REPOSITORY
- GITHUB_ACTOR
