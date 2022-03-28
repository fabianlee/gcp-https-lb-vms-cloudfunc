

module "gcp-networks" {
  source = "../modules/gcp-networks"

  network_name = var.network_name
  subnetwork_region = var.region
  firewall_internal_allow_cidr = var.firewall_internal_allow_cidr
}

