# Terra kubernetes linter

A Github Action to automatically lint kubernetes manifests

### Workflow
* Add this action to your repo
* Commit some changes to kubernetes manifest
* Push to any branch
* On push to any branch, the action will run linting policies against manifests and report any violations

#### Inputs
| Name | Default | Required | Description|
| ---- | ------- | -------- | ---------- |
| `manifest_dir` |  | Yes | Directory where manifest reside|
| `custom_policies_dir` |  | No | Directories were custom policies reside |
| `ignore_default_policy` | false | No | Whether to lint against default policies|
