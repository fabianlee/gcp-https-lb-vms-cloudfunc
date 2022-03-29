
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "vpc_network" {
  name = var.network_name
  auto_create_subnetworks = false
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "subnetwork" {
  for_each = var.subnetworks
  provider      = google-beta

  name          = each.key
  ip_cidr_range = each.value.cidr
  region        = var.subnetwork_region
  network       = google_compute_network.vpc_network.name
 
  # vms in this subnet can reach Google API 
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = each.value.pods_cidr
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = each.value.services_cidr
  }

  # https://cloud.google.com/sdk/gcloud/reference/compute/networks/subnets/create#--purpose
  purpose       = each.value.purpose
}

resource "google_compute_subnetwork" "https-lb-subnetwork" {
  provider      = google-beta

  name          = "https-lb-only-subnet"
  ip_cidr_range = var.https_lb_only_subnet_cidr
  region        = var.subnetwork_region
  network       = google_compute_network.vpc_network.name
  role          = "ACTIVE"
 
  # https://cloud.google.com/sdk/gcloud/reference/compute/networks/subnets/create#--purpose
  purpose       = "INTERNAL_HTTPS_LOAD_BALANCER" # internal regioal HTTPS LB
  # https://cloud.google.com/load-balancing/docs/l7-internal/proxy-only-subnets
  # the value below is actually preferred
  #purpose       = "REGIONAL_MANAGED_PROXY" # internal regional HTTPS LB
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall
resource "google_compute_firewall" "firewall-all-internal" {

  name       = "${google_compute_network.vpc_network.name}-allow-internal"
  network    = google_compute_network.vpc_network.name
  direction  = "INGRESS"
  priority   = 1000

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.firewall_internal_allow_cidr]
}

resource "google_compute_firewall" "firewall-allow-ssh" {

  name    = "${google_compute_network.vpc_network.name}-ext-ssh-allow"
  network = google_compute_network.vpc_network.name
  direction  = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["pubjumpbox"]
}

# google sources of health checks
# https://cloud.google.com/load-balancing/docs/health-checks#firewall_rules
resource "google_compute_firewall" "firewall-allow-health-checks" {

  name    = "${google_compute_network.vpc_network.name}-google-health-checks"
  network = google_compute_network.vpc_network.name
  direction  = "INGRESS"

  source_ranges = ["35.191.0.0/16","130.211.0.0/22"]
  target_tags   = ["allow-health-checks"]

  allow {
    protocol = "tcp"
  }
}

resource "google_compute_address" "internal_ip" {
  for_each = var.subnetworks
  name         = "${each.key}-int-ip"
  address      = cidrhost(each.value.cidr,99)
  
  subnetwork   = google_compute_subnetwork.subnetwork[each.key].id
  region       = var.subnetwork_region
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
}

