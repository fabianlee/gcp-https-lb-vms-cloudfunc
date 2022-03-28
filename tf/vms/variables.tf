variable project_id {}
variable region {}
variable zone {}

variable network_name {}

variable "vms" {
  type = map
  default = {
  "apache1-10-0-90-0" = { is_public=true, subnetwork="pub-10-0-90-0", zone="b", scopes=[], tags=["pubjumpbox","allow-health-checks"] },
  "apache2-10-0-90-0" = { is_public=true, subnetwork="pub-10-0-90-0", zone="c", scopes=[], tags=["pubjumpbox","allow-health-checks"] }
  }
}

