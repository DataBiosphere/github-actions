# Policies for probes
package main

import data.kubernetes

# Manifest name
name = input.metadata.labels["app.kubernetes.io/name"]

has_probe(probe_type) {
  input.kind == "Deployment"
  input.spec.containers[_][probe_type]
}

deny_readiness_prob[msg] {
  has_probe("readinessProbe")
  msg = sprintf("%s must have readinessProbe.", [name])
}

deny_liveness_probe[msg] {
  has_probe("livenessProbe")
  msg = sprintf("%s must have livenessProbe.", [name])
}

deny_startup_probe[msg] {
  has_probe("startupProbe")
  msg = sprintf("%s Must have startupProbe", [name])
}
