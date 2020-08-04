provider "google" {
  project = var.google_project
  region  = var.region
}

provider "google" {
  alias   = "dns"
  project = var.dns_google_project
  region  = var.region
}

terraform {
  backend "gcs" {
    bucket = "terra-preview-env-tfstate"
    prefix = "tfstate"
  }
  required_version = ">= 0.12.19"
  required_providers {
    google      = ">= 3.2.0"
    google-beta = ">= 3.2.0"
  }
}
