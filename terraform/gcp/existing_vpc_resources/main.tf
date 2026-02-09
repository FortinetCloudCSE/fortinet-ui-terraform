terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

locals {
  # Common labels applied to all resources
  common_labels = {
    customer_prefix = var.cp
    environment     = var.env
    managed_by      = "terraform"
  }

  # Availability zones (full zone names)
  zone_1 = var.gcp_zone_1
  zone_2 = var.gcp_zone_2
}
