# General policies for deployments
package main

import data.kubernetes

# Manifest name
name = input.metadata.labels["app.kubernetes.io/name"]

# Constant value as defined in README
# Please don't update
min_required_replicas = 3
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

deny_replicas[msg] {
  input.kind == "Deployment"
  input.metadata.annotations["bio.terra.linter/replicas_exception"] != "enabled"
  input.spec.replicas < min_required_replicas
  msg := sprintf("Must have at least 3 replicas. %s has %d replicas.", [name, input.spec.replicas])
}

deny_revision_history[msg] {
  input.kind == "Deployment"
  input.spec.revisionHistoryLimit != revision_history_limit
  msg := sprintf("%s should set revisionHistoryLimit to 0. Currently is: %d", [name, input.spec.revisionHistoryLimit])
}
