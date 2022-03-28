

module "gcp-cloudnat" {
  source = "../modules/gcp-cloudnat"
  # flag to determine whether we deploy Cloud NAT for private networks
  count   = var.use_cloud_nat ? 1:0

  network_name = var.network_name
}

