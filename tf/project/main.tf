# imported already existing gcp project using:
# terraform import --var-file=../envs/all.tfvars --state=../envs/project.tfstate module.gcp-project.google_project.project my-gkeproj1-xxxx


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
module "gcp-project" {
  source = "../modules/gcp-project"

  project_name = var.project_name
  additional_services_list = var.additional_services_list

  region = var.region
  zone = var.zone
  network_name = var.network_name
}

