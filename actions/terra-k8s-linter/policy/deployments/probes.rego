# Probe will prevent a pod from serving traffic before the application has
# fully started, as well as prevent a broken deployment from continuing. It will
# also prevent the pod from serving traffic if the status endpoint starts to
# fail at any point after startup
package main

import data.kubernetes

# Manifest name
name = input.metadata.name

deny_readiness_probe[msg] {
  input.kind == "Deployment"
	input.spec.containers["readinessProbe"]
  msg := sprintf("%s must have readinessProbe.", [name])
}

#  A liveness probe will automatically restart a container after the status
#  probe fails
deny_liveness_probe[msg] {
	input.kind == "Deployment"
	input.spec.containers["livenessProbe"]
  msg := sprintf("%s must have livenessProbe.", [name])
}

deny_startup_probe[msg] {
	input.kind == "Deployment"
	input.spec.containers["startupProbe"]
  msg := sprintf("%s Must have startupProbe", [name])
}
