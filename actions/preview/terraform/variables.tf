#
# General Vars
#
variable "google_project" {
  type        = string
  description = "The google project in which to create resources"
}
variable "dns_google_project" {
  type        = string
  default     = "dsp-devops"
  description = "The google project for DNS records"
}
variable "region" {
  type        = string
  default     = "us-central1"
  description = "GCP region to create resources in"
}
variable "cluster" {
  type        = string
  description = "Terra GKE cluster suffix, whatever is after terra-"
}
variable "cluster_short" {
  type        = string
  description = "Optional short cluster name"
  default     = ""
}
variable "owner" {
  type        = string
  description = "Environment or developer. Defaults to TF workspace name if left blank."
  default     = ""
}
locals {
  owner   = var.owner == "" ? terraform.workspace : var.owner
}

#
# DNS Vars
#
variable "dns_zone_name" {
  type        = string
  description = "DNS zone name"
  default     = "dsp-envs"
}

#
# Service Vars
#
variable "terra_apps" {
  type = map(string)
  description = "Map of app Helm chart names to ingress hostnames"
  default = {
    workspacemanager = "workspace"
  }
}

variable "versions" {
  type = string
  description = "Base64 encoded JSON string of version overrides"
  default = "Cg=="
}
