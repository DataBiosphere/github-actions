#
# General Vars
#
variable "google_project" {
  type        = string
  default     = "terra-kernel-k8s"
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
  default     = "integration"
}
variable "cluster_short" {
  type        = string
  description = "Optional short cluster name"
  default     = "integ"
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
locals {
  subdomain_name = ".${local.owner}.preview"
}

#
# Service Vars
#
variable "terra_apps" {
  type = map(bool)
  description = "Terra apps to enable"
  default = {
    workspace_manager = true
  }
}

variable "versions" {
  type = string
  description = "Base64 encoded JSON string of version overrides"
  default = "Cg=="
}
