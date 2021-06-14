package main

import data.kubernetes


name = input.metadata.name

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
	input.metadata.annotations["bio.terra.linter/replicas_exception"] != "disabled"
  input.spec.replicas < 3
  msg := sprintf("Must have at least 3 replicas. %s has %d replicas.", [name, input.spec.replicas])
}

deny_revision_history[msg] {
  input.kind == "Deployment"
  input.spec.revisionHistoryLimit != 0
  msg := sprintf("%s should set revisionHistoryLimit to 0. Currently is: %b", [name, input.spec.revisionHistoryLimit])
}

exception[rules] {
  input.kind == "Deployment"
  startswith(input.metadata.name , "datarepo-")
  rules := ["deny"]
}
