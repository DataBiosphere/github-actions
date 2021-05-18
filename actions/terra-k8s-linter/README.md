# Terra kubernetes linter

A Github Action to automatically lint kubernetes manifests

### Linting policies
* Deployments should end in `-deployment`
* Service accounts should follow the naming convention `<chartname>-sa`
* Deployments should set revisionHistoryLimit to 0
* All Deployments should have readiness/liveness probes
* Standard labels are added to pod template metadata, not just deployment metadata as defined in K8s [recommended lables](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/).

### Workflow
* Add this action to your repo
* Commit some changes to kubernetes manifest
* Push to any branch
* On push to any branch, the action will run linting policies against manifests and report any violations

#### Inputs
| Name | Default | Required | Description|
| ---- | ------- | -------- | ---------- |
| `manifest_dir` |  | Yes | Directory where manifest reside|
| `custom_policies_dir` |  | No | Directories were additional custom policies reside |
| `ignore_default_policy` | false | No | Whether to lint against default policies|
