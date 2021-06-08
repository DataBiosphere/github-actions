package main

import data.kubernetes


name = input.metadata.name

required_deployment_labels {
  input.metadata.labels.app.kubernetes.io/name
  input.metadata.labels["app.kubernetes.io/instance"]
  input.metadata.labels["app.kubernetes.io/version"]
  input.metadata.labels["app.kubernetes.io/component"]
  input.metadata.labels["app.kubernetes.io/part-of"]
  input.metadata.labels["app.kubernetes.io/managed-by"]
}

deny_required_deployment_labels[msg] {
  input.kind == "Deployment"
  not required_deployment_labels
  msg = sprintf("%s must include Kubernetes recommended labels", [name])
}

deny_proper_service_account_name[msg] {
  input.kind == "Deployment"
  service_account_name := input.spec.template.spec.serviceAccountName
  exp_service_account_name := sprintf("%s%s", [input.metadata.labels.app, "-sa"])
  not service_account_name == exp_service_account_name
  msg := sprintf("Service account name expected: %s.  Service account name recieved: %s", [exp_service_account_name, service_account_name])
}

deny_proper_deployment_name[msg] {
  input.kind == "Deployment"
  not endswith(name, "-deployment")
  msg := sprintf("%s should end in '-deployment'.", [name])
}

deny_replicas_count[msg] {
  input.kind == "Deployment"
  not input.spec.replicas >= 3
  msg := sprintf("Must have at least 3 replicas. %s has %b replicas.", [name, input.spec.replicas])
}

deny_revision_history[msg] {
  input.kind == "Deployment"
  input.spec.revisionHistoryLimit != 0
  msg := sprintf("%s should set revisionHistoryLimit to 0", [name])
}
