# Terra kubernetes linter

A Github Action to automatically lint kubernetes manifests

### Workflow
* Add this action to your repo
* Commit some changes to kubernetes manifest
* Push to any branch
* On push to any branch, the action will run linting policies against manifests and report any violations


### Linting policies
* Deployments should end in `-deployment`
* Service accounts: <chartname>-sa
* Deployments should set revisionHistoryLimit to 0
* All Deployments should have readiness/liveness probes
* Standard labels are added to pod template metadata, not just deployment metadata as defined in K8s (recommended lables[https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/].
