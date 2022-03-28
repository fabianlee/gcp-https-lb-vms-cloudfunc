output "project_id" {
  sensitive = false
  value = module.gcp-project.project_id
}
output "mybilling" {
  value = module.gcp-project.mybilling
}
output "projnumber" {
  value = module.gcp-project.projnumber
}

