package main

import data.kubernetes


name = input.metadata.name

deny_proper_service_account_name[msg] {
  input.kind == "Deployment"
  app_name := input.spec.template.spec.name
  exp_service_account_name := sprintf("%s%s", [app_name, "-sa"])
  not service_account_name == exp_service_account_name
  msg := sprintf("Service account name expected: %s.  Service account name recieved: %s", [exp_service_account_name, service_account_name])
}

deny_proper_deployment_name[msg] {
  input.kind == "Deployment"
  not endswith(name, "-deployment")
  msg := sprintf("Deployment name needs to end in '-deployment'. Current name: %s", [name])
}
