
data "google_billing_account" "acct" {
  display_name = "My Billing Account"
  open         = true
}

resource "random_id" "rand_project_id" {
  byte_length = 6
}

resource "google_project" "project" {
  name       = var.project_name
  # remove uppercase letters
  project_id = "${var.project_name}-${lower(random_id.rand_project_id.id)}"

  # if set to false, will delete 'default'
  # this leaves networking in current state
  auto_create_network = true

  billing_account = data.google_billing_account.acct.id
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "services" {
  for_each = toset(var.project_services_list)

  project = google_project.project.project_id
  service = each.value

  disable_dependent_services = true
}

resource "google_project_service" "asm-services" {
  for_each = toset(var.asm_services_list)

  project = google_project.project.project_id
  service = each.value

  disable_dependent_services = true
}

resource "google_project_service" "additional-services" {
  for_each = toset(var.additional_services_list)

  project = google_project.project.project_id
  service = each.value

  disable_dependent_services = true
}

data "template_file" "all_tfvars" {
  template = file("${path.module}/all.tfvars.template")
  vars = {
    project_name = var.project_name
    project_id = google_project.project.project_id
    region = var.region
    zone = var.zone
    network_name = var.network_name 
  }
}

resource "local_file" "all_tfvars" {
  content = data.template_file.all_tfvars.rendered
  filename = "${path.module}/../../envs/all.tfvars"
}

output "project_id" {
  value = google_project.project.project_id
}
output "mybilling" {
  value = data.google_billing_account.acct.id
}
output "projnumber" {
  value = google_project.project.number
}
