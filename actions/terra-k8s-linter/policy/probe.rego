package main

import data.kubernetes


name = input.metadata.name

required_probes {
  input.spec.template.spec.containers["readinessProbe"]
  input.spec.template.spec.containers["livenessProbe"]
  input.spec.template.spec.containers["startupProbe"]
}

deny_liveness_probe[msg] {
	not required_probes input.spec.template.spec.containers["livenessProbe"]
	msg = sprintf("%s Must have liveness probe.", [name])
}

deny_readiness_probe[msg] {
	not required_probes input.spec.template.spec.containers["readinessProbe"]
	msg = sprintf("%s Must have readiness probe.", [name])
}

deny_startup_probe[msg] {
	not required_probes input.spec.template.spec.containers["startupProbe"]
	msg = sprintf("%s Must have start up probe.", [name])
}
