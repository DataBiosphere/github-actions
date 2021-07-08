### Deployment Linting policies

#### General policies

Policies can be found in [deny.rego](https://github.com/DataBiosphere/github-actions/blob/master/actions/terra-k8s-linter/policy/deployments/deny.rego). These are policies that can't don't fall in s particular group and are general in nature.
* Deployments should set revisionHistoryLimit to 0
    * The only reason to keep old revisions around is to use kubectl rollout to rollback. But if you do that, you will end up running old code on new/updated configmaps (bad!). We already have a Right Way to rollback (sync to earlier revision of terra-helmfile), so let’s not keep old revisions around and potentially leave the door open for devs to do the Wrong Thing. (Plus, old deployments clutter up the ArgoCD UI)
* Standard labels are added to pod template metadata, not just deployment metadata as defined in K8s [recommended lables](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/).
