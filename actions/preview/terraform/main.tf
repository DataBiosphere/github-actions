module "env" {
  source = "github.com/broadinstitute/terraform-ap-modules.git//terra-preview-env?ref=gm-preview"

  providers = {
    google.target      = google
    google.dns         = google.dns
  }

  google_project = var.google_project
  cluster        = var.cluster
  cluster_short  = var.cluster_short
  owner          = var.owner

  dns_zone_name = var.dns_zone_name

  terra_apps = var.terra_apps

  versions = var.versions
}
