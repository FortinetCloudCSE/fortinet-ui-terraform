#====================================================================================================
# SPOKE VPC NETWORKS (East / West)
#====================================================================================================
# East and west spoke VPCs for testing traffic flows through FortiGate inspection.
# Each spoke has a single subnet with a Linux test instance.
# Spoke VPCs peer with the inspection VPC so traffic can be routed through FortiGates.

#====================================================================================================
# EAST SPOKE VPC
#====================================================================================================

resource "google_compute_network" "east" {
  count                   = var.enable_spoke_vpcs ? 1 : 0
  name                    = "${var.cp}-${var.env}-east-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "east" {
  count         = var.enable_spoke_vpcs ? 1 : 0
  name          = "${var.cp}-${var.env}-east-subnet"
  ip_cidr_range = var.vpc_cidr_east
  region        = var.gcp_region
  network       = google_compute_network.east[0].id
}

# Firewall rules - East
resource "google_compute_firewall" "east_allow_ssh" {
  count   = var.enable_spoke_vpcs ? 1 : 0
  name    = "${var.cp}-${var.env}-east-allow-ssh"
  network = google_compute_network.east[0].name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.management_cidr]
  target_tags   = ["spoke-instance"]
}

resource "google_compute_firewall" "east_allow_internal" {
  count   = var.enable_spoke_vpcs ? 1 : 0
  name    = "${var.cp}-${var.env}-east-allow-internal"
  network = google_compute_network.east[0].name

  allow {
    protocol = "all"
  }

  source_ranges = [var.vpc_cidr_east, var.vpc_cidr_inspection]
}

# VPC Peering: East <-> Inspection
resource "google_compute_network_peering" "east_to_inspection" {
  count        = var.enable_spoke_vpcs ? 1 : 0
  name         = "${var.cp}-${var.env}-east-to-inspection"
  network      = google_compute_network.east[0].self_link
  peer_network = google_compute_network.inspection.self_link

  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "inspection_to_east" {
  count        = var.enable_spoke_vpcs ? 1 : 0
  name         = "${var.cp}-${var.env}-inspection-to-east"
  network      = google_compute_network.inspection.self_link
  peer_network = google_compute_network.east[0].self_link

  export_custom_routes = true
  import_custom_routes = true

  depends_on = [google_compute_network_peering.east_to_inspection]
}

# East test instance
resource "google_compute_instance" "east_linux" {
  count        = var.enable_spoke_vpcs && var.enable_instances ? 1 : 0
  name         = "${var.cp}-${var.env}-east-linux"
  machine_type = "e2-micro"
  zone         = local.zone_1

  tags = ["spoke-instance"]

  labels = merge(local.common_labels, {
    role = "spoke-east"
  })

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.east[0].id

    access_config {
      # Ephemeral public IP for testing
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_username}:${file(pathexpand(var.ssh_public_key_path))}"
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y apache2 net-tools iperf3
    systemctl enable apache2
    systemctl start apache2
    echo "<h1>${var.cp}-${var.env} East Spoke Instance</h1>" > /var/www/html/index.html
  EOF

  service_account {
    scopes = ["cloud-platform"]
  }
}

#====================================================================================================
# WEST SPOKE VPC
#====================================================================================================

resource "google_compute_network" "west" {
  count                   = var.enable_spoke_vpcs ? 1 : 0
  name                    = "${var.cp}-${var.env}-west-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "west" {
  count         = var.enable_spoke_vpcs ? 1 : 0
  name          = "${var.cp}-${var.env}-west-subnet"
  ip_cidr_range = var.vpc_cidr_west
  region        = var.gcp_region
  network       = google_compute_network.west[0].id
}

# Firewall rules - West
resource "google_compute_firewall" "west_allow_ssh" {
  count   = var.enable_spoke_vpcs ? 1 : 0
  name    = "${var.cp}-${var.env}-west-allow-ssh"
  network = google_compute_network.west[0].name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.management_cidr]
  target_tags   = ["spoke-instance"]
}

resource "google_compute_firewall" "west_allow_internal" {
  count   = var.enable_spoke_vpcs ? 1 : 0
  name    = "${var.cp}-${var.env}-west-allow-internal"
  network = google_compute_network.west[0].name

  allow {
    protocol = "all"
  }

  source_ranges = [var.vpc_cidr_west, var.vpc_cidr_inspection]
}

# VPC Peering: West <-> Inspection
resource "google_compute_network_peering" "west_to_inspection" {
  count        = var.enable_spoke_vpcs ? 1 : 0
  name         = "${var.cp}-${var.env}-west-to-inspection"
  network      = google_compute_network.west[0].self_link
  peer_network = google_compute_network.inspection.self_link

  export_custom_routes = true
  import_custom_routes = true

  # Can't have multiple peerings being created simultaneously to the same network
  depends_on = [google_compute_network_peering.inspection_to_east]
}

resource "google_compute_network_peering" "inspection_to_west" {
  count        = var.enable_spoke_vpcs ? 1 : 0
  name         = "${var.cp}-${var.env}-inspection-to-west"
  network      = google_compute_network.inspection.self_link
  peer_network = google_compute_network.west[0].self_link

  export_custom_routes = true
  import_custom_routes = true

  depends_on = [google_compute_network_peering.west_to_inspection]
}

# West test instance
resource "google_compute_instance" "west_linux" {
  count        = var.enable_spoke_vpcs && var.enable_instances ? 1 : 0
  name         = "${var.cp}-${var.env}-west-linux"
  machine_type = "e2-micro"
  zone         = local.zone_2

  tags = ["spoke-instance"]

  labels = merge(local.common_labels, {
    role = "spoke-west"
  })

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.west[0].id

    access_config {
      # Ephemeral public IP for testing
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_username}:${file(pathexpand(var.ssh_public_key_path))}"
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y apache2 net-tools iperf3
    systemctl enable apache2
    systemctl start apache2
    echo "<h1>${var.cp}-${var.env} West Spoke Instance</h1>" > /var/www/html/index.html
  EOF

  service_account {
    scopes = ["cloud-platform"]
  }
}
