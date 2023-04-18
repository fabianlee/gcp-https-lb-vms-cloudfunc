#!/bin/bash
#
# Creates Python gen2 Cloud Function then creates external HTTPS LB to expose with custom certificate
#

# if --do-not-expose is non-empty then we
# skip creation of: ssl-certificates, target-https-proxies and forwarding-rule
# which is not necessary if this Cloud Function is going to be inserted into an existing LB
do_not_expose="$1"
if [ -n "$do_not_expose" ]; then
  echo "Will create objects, but NOT expose to external with forwarding-rule and target-https-proxies"
else
  echo "Going to expose Cloud Function with external HTTPS LB"
fi

funcname=maintgen2
entry_point=maintenance_switch
channel=beta

region=$(gcloud config get compute/region)
project_id=$(gcloud config get project)
[[ (-n "$region") && (-n "$project_id") ]] || { echo "ERROR could not pull region or project id"; exit 1; }

export PYTHONWARNINGS="ignore:Unverified HTTPS request"
gcloud services enable cloudfunctions.googleapis.com cloudbuild.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com run.googleapis.com artifactregistry.googleapis.com containerregistry.googleapis.com

gcloud artifacts repositories create my-repo --location=$region --repository-format=docker

gcloud $channel functions deploy $funcname --entry-point=$entry_point --gen2 --runtime python38 --trigger-http --allow-unauthenticated --min-instances=1 --region=$region

gcloud $channel run services update $funcname --concurrency 100 --cpu=1 --region=$region

gcloud $channel functions describe $funcname --format "value(serviceConfig.uri)" --region=$region --gen2

gcloud compute network-endpoint-groups create ${funcname}-neg --region=$region --network-endpoint-type=serverless --cloud-function-name=$funcname

gcloud compute backend-services create ${funcname}-backend --load-balancing-scheme=EXTERNAL --global

gcloud compute backend-services add-backend ${funcname}-backend --global --network-endpoint-group=${funcname}-neg --network-endpoint-group-region=$region

gcloud compute url-maps create ${funcname}-lb1 --default-service=${funcname}-backend --global

if [ -z "$do_not_expose" ]; then

  # certificate and key for TLS
  domain=${funcname}.fabianlee.org
  if [ ! -f /tmp/$domain.key ]; then
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /tmp/$domain.key -out /tmp/$domain.crt \
    -subj "/C=US/ST=CA/L=SFO/O=myorg/CN=$domain"
  fi
  gcloud compute ssl-certificates create ${funcname}-lbcert --certificate=/tmp/$domain.crt --private-key=/tmp/$domain.key --global
  
  gcloud compute target-https-proxies create ${funcname}-https-proxy --ssl-certificates=${funcname}-lbcert --url-map=${funcname}-lb1 --global
  
  echo "health checks are not supported for backend services with serverless NEG backends. no need to create health check"
  
  gcloud compute forwarding-rules create ${funcname}-frontend --load-balancing-scheme=EXTERNAL --target-https-proxy=${funcname}-https-proxy --ports=443 --global
  
  echo "Here is the IP address of the ${funcname}-frontend Load Balancer"
  gcloud compute forwarding-rules describe ${funcname}-frontend  --global --format="value(IPAddress)"

else

  echo "SKIP exposing $funcname with target-https-proxies and forwarding-rules, which is fine if we just want to inject the Cloud Function into an existing LB chain"

fi

echo "Here is the direct URL to the Cloud Function"
gcloud $channel functions describe $funcname --region $region --gen2 --format="value(serviceConfig.uri)"

