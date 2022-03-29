#!/bin/bash
#
# Creates GCP HTTPS LB internal from 2 unmanaged instance groups (2 VM instances in different zones)
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

lb_type="$1"
network_name="$2"
subnet_name="$3"
region="$4"
domain="$5"
if [[ -z "$lb_type" || -z "$network_name" || -z "$subnet_name" || -z "$region" || -z "$domain" ]]; then
  echo "Usage: lb_type=int|ext networkName subnetwork region domain"
  echo "Example: int mynetwork pub-10-0-90-0 us-east1 httpslb.fabianlee.org"
  exit 1
fi

# managed instance groups are for multiple identical vm with template instance
# we want unmanaged instance groups that allow for fleet of VMs
function create_unmanaged_ig() {
  name="$1"
  region="$2"
  zone_suffix="$3"
  vm_instance="$4"

  # https://cloud.google.com/sdk/gcloud/reference/compute/instance-groups/unmanaged/create
  gcloud compute instance-groups unmanaged create $name-${zone_suffix} --zone=${region}-${zone_suffix}
  gcloud compute instance-groups unmanaged set-named-ports $name-${zone_suffix} --named-ports=http:80 --zone=${region}-${zone_suffix}
  gcloud compute instance-groups unmanaged add-instances $name-${zone_suffix} --instances=$vm_instance --zone=${region}-${zone_suffix}
}

function create_backend_service() {
  backend_name="$1"
  region="$2"
  network="$3"
  healthcheck="$4"

  # https://cloud.google.com/sdk/gcloud/reference/compute/backend-services/create#--health-checks
  # network flag is for external https LB
  # flag http-health-checks is not supported only health-checks
  gcloud compute backend-services create $backend_name --health-checks=$healthcheck --health-checks-region=$region --region=$region --port-name=http --protocol=HTTP --load-balancing-scheme=INTERNAL_MANAGED --logging-sample-rate=1
  # --locality-lb-policy=ROUND_ROBIN (alpha channel of 377 if you want to add, need logic to support)
}
function add_instance_group_to_backend() {
  backend_name="$1"
  instance_group_prefix="$2"
  region="$3"
  zone_suffix="$4"

  # https://cloud.google.com/sdk/gcloud/reference/compute/backend-services/update-backend
  gcloud compute backend-services add-backend $backend_name --instance-group=${instance_group_prefix}-${zone_suffix} --instance-group-zone=${region}-${zone_suffix} --region=$region
}

project_id=$(gcloud config get project)
echo "project_id is $project_id"
if [ "$lb_type" = "int" ]; then
  instance_group_prefix=intlb-ig
  healthcheck_name=intlb-health
  backend_name=intlb-backend
  target_https_proxy_name=intlb-target-https-proxy
  lb_name=intlb-lb1
  fwd_rule_name=intlb-frontend
elif [ "$lb_type" = "ext" ]; then
  instance_group_prefix=extlb-ig
  healthcheck_name=extlb-health
  backend_name=extlb-backend
  target_https_proxy_name=extlb-target-https-proxy
  lb_name=extlb-lb1
  fwd_rule_name=intlb-frontend
else
  echo "ERROR do not recognize the lb_type $lb_type"
  exit 3
fi

set -x

create_unmanaged_ig "$instance_group_prefix" "$region" "b" "apache1-10-0-90-0"
create_unmanaged_ig "$instance_group_prefix" "$region" "c" "apache2-10-0-90-0"

# https://cloud.google.com/sdk/gcloud/reference/compute/health-checks/create/http
# --use-serving-port
gcloud compute health-checks create http $healthcheck_name --region=$region --host='' --request-path=/index.html --port=80 --enable-logging

create_backend_service $backend_name "$region" "mynetwork" $healthcheck_name
add_instance_group_to_backend $backend_name $instance_group_prefix "$region" "b"
add_instance_group_to_backend $backend_name $instance_group_prefix "$region" "c"

gcloud compute ssl-certificates create lbcert1 --certificate=/tmp/$domain.crt --private-key=/tmp/$domain.key --region=$region --project=$project_id

# https://cloud.google.com/sdk/gcloud/reference/compute/target-https-proxies/create
# create proxy map and url map
gcloud compute url-maps create $lb_name --description="$lb_name LB" --default-service=$backend_name --region=$region
gcloud compute target-https-proxies create $target_https_proxy_name --url-map-region=$region --url-map $lb_name --region=$region --ssl-certificates-region=$region --ssl-certificates=lbcert1
# if adding an insecure http backend
#gcloud compute target-http-proxies create $target_http_proxy_name --url-map intlb-url-map --region=$region

# going to use ephemeral internal IP with DNS instead of static internal IP
# https://cloud.google.com/compute/docs/ip-addresses/reserve-static-internal-ip-address
#internal_address_name=intlb1-address
#gcloud compute addresses create $internal_address_name --region=$region --subnet=$subnet_name --addresses 10.0.90.17

# https://cloud.google.com/sdk/gcloud/reference/compute/forwarding-rules/create
# https://cloud.google.com/load-balancing/docs/dns-names
# backend-service not used for INTERNAL_MANAGED
# service-label is only for internal https lb for internal dns entry
gcloud compute forwarding-rules create $fwd_rule_name --region=$region --subnet-region=$region --load-balancing-scheme=INTERNAL_MANAGED --subnet=$subnet_name --network=$network_name --ports=443 --target-https-proxy=$target_https_proxy_name --target-https-proxy-region=$region --service-label=intlb-frontend-dns
# --address=$internal_address_name

exit 0
