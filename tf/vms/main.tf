

module "gcp-vms" {
  source = "../modules/gcp-vms"
  for_each = var.vms

  #vm_name    = "vm-${each.key}"
  vm_name    = each.key
  project    = var.project_id
  region     = var.region
  zone       = "${var.region}-${each.value.zone}"
  vm_network = var.network_name

  vm_subnetwork   = each.value.subnetwork
  has_public_ip   = each.value.is_public
  vm_scopes       = each.value.scopes
  vm_network_tags = each.value.tags
}


# if object: terraform output -json <varname> | jq
# if value:  terraform output -raw <varname>
output "module_internal_ip" {
  value = zipmap(
    keys(module.gcp-vms),
    values(module.gcp-vms)[*].internal_ip
  )
}
output "module_public_ip" {
  value = zipmap(
    keys(module.gcp-vms),
    values(module.gcp-vms)[*].public_ip
  )
}
