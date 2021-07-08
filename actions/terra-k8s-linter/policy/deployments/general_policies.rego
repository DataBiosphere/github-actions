# General policies for deployments
package main

import data.kubernetes

# Manifest name
name = input.metadata.name

# Constant value as defined in README
# Please don't update
revision_history_limit = 0

# Required standard labels as defined by Kubernetes
required_deployment_labels {
  input.metadata.labels["app.kubernetes.io/name"]
  input.metadata.labels["app.kubernetes.io/instance"]
  input.metadata.labels["helm.sh/chart"]
  input.metadata.labels["app.kubernetes.io/managed-by"]
}

deny_required_deployment_labels[msg] {
  input.kind == "Deployment"
  not required_deployment_labels
  msg = sprintf("%s must include Kubernetes recommended labels", [name])
}

deny_revision_history[msg] {
  input.kind == "Deployment"
  input.spec.revisionHistoryLimit != revision_history_limit
  msg = sprintf("%s should set revisionHistoryLimit to %d. Currently is: %d", [name, revision_history_limit,  input.spec.revisionHistoryLimit])
}
