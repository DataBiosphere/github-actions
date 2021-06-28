# Policies dealing with naming conventions
package main

import data.kubernetes

# Manifest name
name = input.metadata.labels["app.kubernetes.io/name"]

deny_proper_service_account_name[msg] {
  input.kind == "Deployment"
  input.metadata.annotations["bio.terra.linter/serviceAccountName_exception"] != "enabled"
  exp_service_account_name := sprintf("%s%s", [name, "-sa"])
  service_account_name := input.spec.template.spec.serviceAccountName
  not service_account_name == exp_service_account_name
  msg := sprintf("Service account name expected: %s. Service account name received: %s", [exp_service_account_name, service_account_name])
}

# Makes it easy to tell a Pod was created by a Deployment and not a CronJob or other thing!
deny_proper_deployment_name[msg] {
  input.kind == "Deployment"
  input.metadata.annotations["bio.terra.linter/deployment_name_exception"] != "enabled"
  not endswith(name, "-deployment")
  msg := sprintf("Deployment name needs to end in '-deployment'. Current name: %s", [name])
}
