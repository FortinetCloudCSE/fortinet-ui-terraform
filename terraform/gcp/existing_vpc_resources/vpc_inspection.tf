#====================================================================================================
# INSPECTION VPC NETWORK
#====================================================================================================
# VPC network for FortiGate inspection with subnets for:
# - Public (untrust) interfaces
# - Private (trust) interfaces
# - Internal Load Balancer
# - HA Sync (heartbeat/session sync)

resource "google_compute_network" "inspection" {
  name                    = "${var.cp}-${var.env}-inspection-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

#====================================================================================================
# Public (Untrust) Subnets
#====================================================================================================

resource "google_compute_subnetwork" "inspection_public_az1" {
  name          = "${var.cp}-${var.env}-inspection-public-az1"
  ip_cidr_range = var.inspection_public_subnet_az1
  region        = var.gcp_region
  network       = google_compute_network.inspection.id
}

resource "google_compute_subnetwork" "inspection_public_az2" {
  name          = "${var.cp}-${var.env}-inspection-public-az2"
  ip_cidr_range = var.inspection_public_subnet_az2
  region        = var.gcp_region
  network       = google_compute_network.inspection.id
}

#====================================================================================================
# Private (Trust) Subnets
#====================================================================================================

resource "google_compute_subnetwork" "inspection_private_az1" {
  name          = "${var.cp}-${var.env}-inspection-private-az1"
  ip_cidr_range = var.inspection_private_subnet_az1
  region        = var.gcp_region
  network       = google_compute_network.inspection.id
}

resource "google_compute_subnetwork" "inspection_private_az2" {
  name          = "${var.cp}-${var.env}-inspection-private-az2"
  ip_cidr_range = var.inspection_private_subnet_az2
  region        = var.gcp_region
  network       = google_compute_network.inspection.id
}

#====================================================================================================
# Internal Load Balancer Subnets
#====================================================================================================

resource "google_compute_subnetwork" "inspection_ilb_az1" {
  name          = "${var.cp}-${var.env}-inspection-ilb-az1"
  ip_cidr_range = var.inspection_ilb_subnet_az1
  region        = var.gcp_region
  network       = google_compute_network.inspection.id
}

resource "google_compute_subnetwork" "inspection_ilb_az2" {
  name          = "${var.cp}-${var.env}-inspection-ilb-az2"
  ip_cidr_range = var.inspection_ilb_subnet_az2
  region        = var.gcp_region
  network       = google_compute_network.inspection.id
}

#====================================================================================================
# HA Sync Subnets (FortiGate heartbeat and session synchronization)
#====================================================================================================

resource "google_compute_subnetwork" "inspection_hasync_az1" {
  name          = "${var.cp}-${var.env}-inspection-hasync-az1"
  ip_cidr_range = var.inspection_hasync_subnet_az1
  region        = var.gcp_region
  network       = google_compute_network.inspection.id
}

resource "google_compute_subnetwork" "inspection_hasync_az2" {
  name          = "${var.cp}-${var.env}-inspection-hasync-az2"
  ip_cidr_range = var.inspection_hasync_subnet_az2
  region        = var.gcp_region
  network       = google_compute_network.inspection.id
}

#====================================================================================================
# Cloud Router (for NAT and dynamic routing)
#====================================================================================================

resource "google_compute_router" "inspection" {
  name    = "${var.cp}-${var.env}-inspection-router"
  region  = var.gcp_region
  network = google_compute_network.inspection.id

  bgp {
    asn = 64514
  }
}

# Cloud NAT for instances without external IPs
resource "google_compute_router_nat" "inspection" {
  name                               = "${var.cp}-${var.env}-inspection-nat"
  router                             = google_compute_router.inspection.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

#====================================================================================================
# Firewall Rules - Inspection VPC
#====================================================================================================

# Allow management access from specified CIDR
resource "google_compute_firewall" "inspection_allow_management" {
  name    = "${var.cp}-${var.env}-inspection-allow-mgmt"
  network = google_compute_network.inspection.name

  allow {
    protocol = "tcp"
    ports    = ["22", "443", "8443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.management_cidr]
  target_tags   = ["fortigate", "management"]
}

# Allow internal traffic between inspection subnets
resource "google_compute_firewall" "inspection_allow_internal" {
  name    = "${var.cp}-${var.env}-inspection-allow-internal"
  network = google_compute_network.inspection.name

  allow {
    protocol = "all"
  }

  source_ranges = [var.vpc_cidr_inspection]
}

# Allow health checks from GCP load balancer ranges
resource "google_compute_firewall" "inspection_allow_health_check" {
  name    = "${var.cp}-${var.env}-inspection-allow-hc"
  network = google_compute_network.inspection.name

  allow {
    protocol = "tcp"
    ports    = ["8008", "8443"]
  }

  # GCP health check source ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["fortigate"]
}

# Allow HA sync traffic between FortiGates
resource "google_compute_firewall" "inspection_allow_ha_sync" {
  name    = "${var.cp}-${var.env}-inspection-allow-hasync"
  network = google_compute_network.inspection.name

  allow {
    protocol = "all"
  }

  source_tags = ["fortigate"]
  target_tags = ["fortigate"]
}
