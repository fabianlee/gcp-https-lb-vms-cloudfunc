#!/bin/bash
#
# Creates GCP HTTPS LB external from 2 unmanaged instance groups (2 VM instances in different zones)
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

lb_type="$1"
network_name="$2"
subnet_name="$3"
region="$4"
domain="$5"
if [[ -z "$lb_type" ||  -z "$network_name" || -z "$subnet_name" || -z "$region" || -z "$domain" ]]; then
  echo "Usage: lb_type=int|ext networkName subnetwork region domain"
  echo "Example: int mynetwork pub-10-0-90-0 us-east1 httpslb.fabianlee.org"
  exit 1
fi

# managed instance groups are for multiple identical vm with template instance
# we want unmanaged instance groups that allow for fleet of VMs
function create_unmanaged_ig() {
  name="$1"
  region="$2"
  vm_instance="$3"
  named_port="$4"

  which_zone=${vm_zones[$vm_instance]}
  zone_suffix=${which_zone##*-} # just the last letter
  echo "Going to created unmanaged instance group for $vm_instance in zone $which_zone"

  # https://cloud.google.com/sdk/gcloud/reference/compute/instance-groups/unmanaged/create
  gcloud compute instance-groups unmanaged create $name-${zone_suffix} --zone=$which_zone
  gcloud compute instance-groups unmanaged set-named-ports $name-${zone_suffix} --named-ports=${named_port} --zone=$which_zone
  gcloud compute instance-groups unmanaged add-instances $name-${zone_suffix} --instances=$vm_instance --zone=$which_zone
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

# create unmanaged instance group for VM in each region
create_unmanaged_ig $instance_group_prefix $region "${vms[0]}" "$named_port"
create_unmanaged_ig $instance_group_prefix $region "${vms[1]}" "$named_port"

# https://cloud.google.com/sdk/gcloud/reference/compute/health-checks/create/http
gcloud compute health-checks create http $healthcheck_name --host='' --request-path=/index.html --port=80 --enable-logging $location_flag

# https://cloud.google.com/sdk/gcloud/reference/compute/backend-services/create#--load-balancing-scheme
# create backend service
# --locality-lb-policy=ROUND_ROBIN (alpha channel of 377 if you want to add, need logic to support)
if [ "$lb_type" = "int" ]; then
  gcloud compute backend-services create $backend_name --health-checks=$healthcheck_name --health-checks-region=$region --port-name=http --protocol=HTTP --load-balancing-scheme=INTERNAL_MANAGED --enable-logging --logging-sample-rate=1 $location_flag
elif [ "$lb_type" = "ext" ]; then
  gcloud compute backend-services create $backend_name --health-checks=$healthcheck_name --port-name=http --protocol=HTTP --load-balancing-scheme=EXTERNAL --enable-logging --logging-sample-rate=1 $location_flag
fi

# modify backend-service, add instance group from each zone
for vm_name in "${vms[@]}"; do
  which_zone=$(gcloud compute instances list --filter=name=$vm_name --format="value(zone)")
  zone_suffix=${which_zone##*-} # just the last letter

  # https://cloud.google.com/sdk/gcloud/reference/compute/backend-services/update-backend
  gcloud compute backend-services add-backend $backend_name --instance-group=${instance_group_prefix}-${zone_suffix} --instance-group-zone=${region}-${zone_suffix} $location_flag
done

# certificate and key for TLS
if [ ! -f /tmp/$domain.key ]; then
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /tmp/$FQDN.key -out /tmp/$FQDN.crt \
  -subj "/C=US/ST=CA/L=SFO/O=myorg/CN=$FQDN"
fi
gcloud compute ssl-certificates create lbcert1 --certificate=/tmp/$domain.crt --private-key=/tmp/$domain.key --project=$project_id $location_flag

# https://cloud.google.com/sdk/gcloud/reference/compute/target-https-proxies/create
# create proxy map and url map
gcloud compute url-maps create $lb_name --default-service=$backend_name $location_flag
# no region for global --region=$region

if [ "$lb_type" = "int" ]; then
  gcloud compute target-https-proxies create $target_https_proxy_name --url-map-region=$region --url-map $lb_name --ssl-certificates-region=$region --ssl-certificates=lbcert1 $location_flag
elif [ "$lb_type" = "ext" ]; then
  gcloud compute target-https-proxies create $target_https_proxy_name --url-map $lb_name --ssl-certificates=lbcert1 --global
fi

# going to use ephemeral IP with DNS instead of static internal IP
# https://cloud.google.com/compute/docs/ip-addresses/reserve-static-internal-ip-address
#internal_address_name=intlb1-address
#gcloud compute addresses create $internal_address_name --region=$region --subnet=$subnet_name --addresses 10.0.90.17

# https://cloud.google.com/sdk/gcloud/reference/compute/forwarding-rules/create
# https://cloud.google.com/load-balancing/docs/dns-names
# service-label is only for internal https lb for internal dns entry
# if network or subnet are in shared VPC, then use fully qualified path e.g. 'projects/'
if [ "$lb_type" = "int" ]; then
  gcloud compute forwarding-rules create $fwd_rule_name --subnet-region=$region --load-balancing-scheme=INTERNAL_MANAGED --subnet=$subnet_name --network=$network_name --ports=443 --target-https-proxy=$target_https_proxy_name --target-https-proxy-region=$region --service-label=intlb-frontend-dns $location_flag
  echo "You can reach int LB at DNS: ${fwd_rule_name}.il7.${region}.lb.${project_id}.internal"
elif [ "$lb_type" = "ext" ]; then
  gcloud compute forwarding-rules create $fwd_rule_name --load-balancing-scheme=EXTERNAL --ports=443 --target-https-proxy=$target_https_proxy_name $location_flag
fi

