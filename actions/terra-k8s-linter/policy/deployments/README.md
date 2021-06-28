### Deployment Linting policies

#### Naming conventions

Policies can be found in [naming_convention.rego](https://github.com/DataBiosphere/github-actions/blob/master/actions/terra-k8s-linter/policy/deployments/naming_convention.rego)
* Deployments should end in `-deployment`
    * Makes it easy to tell a Pod was created by a Deployment and not a CronJob or other thing!
* Service accounts should follow the naming convention `<application name>-sa`
    * Makes is easier to map the service account to the application

#### General policies

Policies can be found in [deny.rego](https://github.com/DataBiosphere/github-actions/blob/master/actions/terra-k8s-linter/policy/deployments/deny.rego). These are policies that can't don't fall in s particular group and are general in nature.
* Deployments should set revisionHistoryLimit to 0
    * The only reason to keep old revisions around is to use kubectl rollout to rollback. But if you do that, you will end up running old code on new/updated configmaps (bad!). We already have a Right Way to rollback (sync to earlier revision of terra-helmfile), so let’s not keep old revisions around and potentially leave the door open for devs to do the Wrong Thing. (Plus, old deployments clutter up the ArgoCD UI)
* Standard labels are added to pod template metadata, not just deployment metadata as defined in K8s [recommended lables](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/).

#### Probes

Policies can be found in [probes.rego](https://github.com/DataBiosphere/github-actions/blob/master/actions/terra-k8s-linter/policy/deployments/probes.rego). These are policies that can't don't fall in s particular group and are general in nature.

* All Deployments should have readiness/liveness probes
    * A readiness probe will prevent a pod from serving traffic before the application has fully started, as well as prevent a broken deployment from continuing. It will also prevent the pod from serving traffic if the status endpoint starts to fail at any point after startup.
    *  A liveness probe will automatically restart a container after the status probe fails for 'x' amount of time
