#!/bin/bash
#
# Deletes GCP HTTPS LB components, internal and external
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

lb_type="$1"
network_name="$2"
subnet_name="$3"
region="$4"
domain="$5"
only_ig="${6:-0}"
if [[ -z "$lb_type" ||  -z "$network_name" || -z "$subnet_name" || -z "$region" || -z "$domain" ]]; then
  echo "Usage: lb_type=int|ext networkName subnetwork region domain"
  echo "Example: int mynetwork pub-10-0-90-0 us-east1 httpslb.fabianlee.org"
  exit 1
fi

function delete_unmanaged_ig() {
  name="$1"
  region="$2"
  vm_instance="$3"
  named_port="$4"

  which_zone=${vm_zones[$vm_instance]}
  zone_suffix=${which_zone##*-} # just the last letter
  echo "Going to delete unmanaged instance group for $vm_instance in zone $which_zone"

  # https://cloud.google.com/sdk/gcloud/reference/compute/instance-groups/unmanaged/create
  gcloud compute instance-groups unmanaged delete $name-${zone_suffix} --zone=$which_zone
}



project_id=$(gcloud config get project)
echo "project_id is $project_id"

# instance group are the same zonal definition, regardless of int or ext
# also, VMs an only participate in a single instance group at a time, so keeping common among multiple LB
instance_group_prefix=lb-ig
if [ "$lb_type" = "int" ]; then
  healthcheck_name=intlb-health
  backend_name=intlb-backend
  target_https_proxy_name=intlb-target-https-proxy
  lb_name=intlb-lb1
  fwd_rule_name=intlb-frontend
  location_flag="--region=$region"
elif [ "$lb_type" = "ext" ]; then
  healthcheck_name=extlb-health
  backend_name=extlb-backend
  target_https_proxy_name=extlb-target-https-proxy
  lb_name=extlb-lb1
  fwd_rule_name=extlb-frontend
  location_flag="--global"
else
  echo "ERROR do not recognize the lb_type $lb_type"
  exit 3
fi


# retrieve zone of each VM, so we can create instance groups
# we have two VM instances, each exposing insecure port 80
vms=(apache1-10-0-90-0 apache2-10-0-90-0)
named_port="http:80"
declare -A vm_zones
for vm_name in "${vms[@]}"; do
  which_zone=$(gcloud compute instances list --filter=name=$vm_name --format="value(zone)")
  zone_suffix=${which_zone##*-} # just the last letter
  vm_zones[$vm_name]=$which_zone
  echo "vm $vm_name is in $which_zone zone suffix '$zone_suffix'"
done


set -x

if [ $only_ig -eq 0 ]; then
gcloud compute forwarding-rules delete $fwd_rule_name $location_flag --quiet
gcloud compute target-https-proxies delete $target_https_proxy_name $location_flag --quiet
gcloud compute url-maps delete $lb_name $location_flag --quiet
gcloud compute backend-services delete $backend_name $location_flag --quiet
gcloud compute health-checks delete http $healthcheck_name $location_flag --quiet
gcloud compute ssl-certificates delete lbcert1 $location_flag --quiet
else
delete_unmanaged_ig $instance_group_prefix $region "${vms[0]}" "$named_port"
delete_unmanaged_ig $instance_group_prefix $region "${vms[1]}" "$named_port"
fi

exit 0

