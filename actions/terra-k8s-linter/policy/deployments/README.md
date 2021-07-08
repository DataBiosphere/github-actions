### Deployment Linting policies

#### General policies

Policies can be found in [deny.rego](https://github.com/DataBiosphere/github-actions/blob/master/actions/terra-k8s-linter/policy/deployments/deny.rego). These are policies that can't don't fall in s particular group and are general in nature.
* Deployments should set revisionHistoryLimit to 0
    * This prevents developers from attempting to rollback deployments using kubectl rollout, which could lead to an old Deployment running with new ConfigMaps; the correct way to roll back is to sync ArgoCD to an earlier revision of terra-helmfile.
* Standard labels are added to deployment template metadata, not just deployment metadata as defined in K8s [recommended lables](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/).
