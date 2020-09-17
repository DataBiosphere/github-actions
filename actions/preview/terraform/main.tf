module "env" {
  source = "github.com/broadinstitute/terraform-ap-modules.git//terra-env?ref=gm-preview-consolidate"

  providers = {
    google.target      = google
    google.dns         = google.dns
    google-beta.target = google-beta
  }

  google_project = var.google_project
  cluster        = var.cluster
  cluster_short  = var.cluster_short
  owner          = var.owner

  preview = true

  terra_apps = var.terra_apps

  dns_zone_name  = var.dns_zone_name
  subdomain_name = local.subdomain_name
  use_subdomain  = true

  versions = var.versions
}
