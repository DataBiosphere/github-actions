# Policies for probes
package main

import data.kubernetes

# Manifest name
name = input.metadata.labels["app.kubernetes.io/name"]
deployment_manifests := [manifests | input[i].kind == "Deployment"; manifests := input[i]]

# readiness_prob(probe) = deployments_no_probe {
# 	deployments_no_probe := [no_probe | deployment_manifests[i].spec.template.spec.containers[_][probe]; no_probe := deployment_manifests[i].metadata.name]
#
# }
#
# deny_liveness_probe[msg] {
#   deployments_no_probe
#   msg = sprintf("%s must have livenessProbe.", [name])
# }

no_probe(probe_type) = [container_name] {
	container_name := {name | deployment_manifests[_].spec.template.spec.containers[i]; name := deployment_manifests[_].spec.template.spec.containers[i]}
  not has_probe[container_name]
}

has_probe[container_name] {
	container_name := { name | deployment_manifests[_].spec.template.spec.containers[i][livenessProbe]; name := deployment_manifests[_].spec.template.spec.containers[i]}[_]
}

deny_liveness_probe[msg] {
  no_probe_containers := no_probe("livenessProbe")
	count(no_probe_containers) != 0
  msg = sprintf("%s must have livenessProbe.", [no_probe_containers])
}
#
# deny_startup_probe[msg] {
#   not has_probe("startupProbe")
#   msg = sprintf("%s Must have startupProbe", [name])
# }
