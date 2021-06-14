package main

import data.kubernetes


name = input.metadata.name

has_probe(probe_type) {
  input.kind == "Deployment"
  endswith(name, "-app")
  input.spec.containers[_][probe_type]
}

deny_readiness_prob[msg] {
  has_probe("readinessProbe")
  msg = sprintf("%s must have readinessProbe probe.", [name])
}

deny_liveness_probe[msg] {
  has_probe("livenessProbe")
  msg = sprintf("%s must have liveness probe.", [name])
}

deny_startup_probe[msg] {
  has_probe("startupProbe")
  msg = sprintf("%s Must have startupProbe", [name])
}