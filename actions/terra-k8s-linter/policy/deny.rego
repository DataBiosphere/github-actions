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

deny_readiness_prob[msg] {
	input.kind == "Deployment"
	not input.spec.template.spec.containers["readinessProbe"]
	msg = sprintf("%s Must have readinessProbe probe.", [name])
}

deny_liveness_probe[msg] {
	input.kind == "Deployment"
	not input.spec.template.spec.containers["livenessProbe"]
	msg = sprintf("%s Must have liveness probe.", [name])
}

deny_startup_probe[msg] {
	input.kind == "Deployment"
	not input.spec.template.spec.containers["startupProbe"]
	msg = sprintf("%s Must have startupProbe", [name])
}

deny[msg] {
  input.kind == "Deployment"
  not input.spec.template.spec.securityContext.runAsNonRoot

  msg := "Containers must not run as root"
}

deny_proper_service_account_name[msg] {
  input.kind == "Deployment"
  service_account_name := input.spec.template.spec.serviceAccountName
  exp_service_account_name := sprintf("%s%s", [name, "-sa"])
  not service_account_name == exp_service_account_name
  msg := sprintf("Service account name expected: %s.  Service account name recieved: %s", [exp_service_account_name, service_account_name])
}

deny_proper_deployment_name[msg] {
  input.kind == "Deployment"
  not endswith(name, "-deployment")
  msg := sprintf("Deployment name needs to end in '-deployment'. Current name: %s", [name])
}

deny_replicas_count[msg] {
  input.kind == "Deployment"
  input.spec.replicas < 3

  msg := sprintf("Must have at least 3 replicas. %s has %b replicas.", [name, input.spec.replicas])
}

deny_revision_history[msg] {
  input.kind == "Deployment"
  input.spec.revisionHistoryLimit != 0

  msg := "Deployments should set revisionHistoryLimit to 0"
}
