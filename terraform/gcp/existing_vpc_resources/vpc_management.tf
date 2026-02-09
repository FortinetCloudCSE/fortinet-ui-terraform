#====================================================================================================
# MANAGEMENT VPC NETWORK
#====================================================================================================
# Separate VPC for management access: jump box, FortiManager, FortiAnalyzer
# Connected to inspection VPC via VPC peering

#====================================================================================================
# VPC Network
#====================================================================================================

resource "google_compute_network" "management" {
  count                   = var.enable_management_vpc ? 1 : 0
  name                    = "${var.cp}-${var.env}-management-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

#====================================================================================================
# Subnets
#====================================================================================================

resource "google_compute_subnetwork" "management_az1" {
  count         = var.enable_management_vpc ? 1 : 0
  name          = "${var.cp}-${var.env}-management-az1"
  ip_cidr_range = var.management_subnet_az1
  region        = var.gcp_region
  network       = google_compute_network.management[0].id
}

resource "google_compute_subnetwork" "management_az2" {
  count         = var.enable_management_vpc ? 1 : 0
  name          = "${var.cp}-${var.env}-management-az2"
  ip_cidr_range = var.management_subnet_az2
  region        = var.gcp_region
  network       = google_compute_network.management[0].id
}

#====================================================================================================
# Cloud Router and NAT
#====================================================================================================

resource "google_compute_router" "management" {
  count   = var.enable_management_vpc ? 1 : 0
  name    = "${var.cp}-${var.env}-management-router"
  region  = var.gcp_region
  network = google_compute_network.management[0].id

  bgp {
    asn = 64515
  }
}

resource "google_compute_router_nat" "management" {
  count                              = var.enable_management_vpc ? 1 : 0
  name                               = "${var.cp}-${var.env}-management-nat"
  router                             = google_compute_router.management[0].name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

#====================================================================================================
# Firewall Rules - Management VPC
#====================================================================================================

resource "google_compute_firewall" "management_allow_ssh" {
  count   = var.enable_management_vpc ? 1 : 0
  name    = "${var.cp}-${var.env}-management-allow-ssh"
  network = google_compute_network.management[0].name

  allow {
    protocol = "tcp"
    ports    = ["22", "443", "8443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.management_cidr]
  target_tags   = ["management", "jump-box"]
}

resource "google_compute_firewall" "management_allow_internal" {
  count   = var.enable_management_vpc ? 1 : 0
  name    = "${var.cp}-${var.env}-management-allow-internal"
  network = google_compute_network.management[0].name

  allow {
    protocol = "all"
  }

  source_ranges = [var.vpc_cidr_management]
}

#====================================================================================================
# VPC Peering: Management <-> Inspection
#====================================================================================================

resource "google_compute_network_peering" "management_to_inspection" {
  count        = var.enable_management_vpc ? 1 : 0
  name         = "${var.cp}-${var.env}-mgmt-to-inspection"
  network      = google_compute_network.management[0].self_link
  peer_network = google_compute_network.inspection.self_link

  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "inspection_to_management" {
  count        = var.enable_management_vpc ? 1 : 0
  name         = "${var.cp}-${var.env}-inspection-to-mgmt"
  network      = google_compute_network.inspection.self_link
  peer_network = google_compute_network.management[0].self_link

  export_custom_routes = true
  import_custom_routes = true

  depends_on = [google_compute_network_peering.management_to_inspection]
}

#====================================================================================================
# Jump Box Instance
#====================================================================================================

resource "google_compute_instance" "jump_box" {
  count        = var.enable_management_vpc && var.enable_instances ? 1 : 0
  name         = "${var.cp}-${var.env}-jump-box"
  machine_type = var.jumpbox_machine_type
  zone         = local.zone_1

  tags = ["jump-box", "management"]

  labels = merge(local.common_labels, {
    role = "jump-box"
  })

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.management_az1[0].id

    access_config {
      # Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_username}:${file(pathexpand(var.ssh_public_key_path))}"
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}
