#!/bin/bash
#
# Creates Python gen2 Cloud Function then creates external HTTPS LB to expose with custom certificate
#

funcname=maintgen2
entry_point=maintenance_switch
channel=beta
region=us-east1

gcloud services enable cloudfunctions.googleapis.com cloudbuild.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com run.googleapis.com artifactregistry.googleapis.com containerregistry.googleapis.com

gcloud artifacts repositories create my-repo --location=$region --repository-format=docker

gcloud $channel functions deploy $funcname --entry-point=$entry_point --gen2 --runtime python38 --trigger-http --allow-unauthenticated --min-instances=1 --region=$region

gcloud $channel run services update $funcname --concurrency 100 --cpu=1 --region=$region

gcloud $channel functions describe $funcname --format "value(serviceConfig.uri)" --region=$region --gen2

gcloud compute network-endpoint-groups create ${funcname}-neg --region=$region --network-endpoint-type=serverless --cloud-run-service=$funcname

gcloud compute backend-services create ${funcname}-backend --load-balancing-scheme=EXTERNAL --global

gcloud compute backend-services add-backend ${funcname}-backend --global --network-endpoint-group=${funcname}-neg --network-endpoint-group-region=$region

gcloud compute url-maps create ${funcname}-lb1 --default-service=${funcname}-backend --global

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
gcloud compute forwarding-rules describe ${funcname}-frontend  --global | yq eval ".IPAddress"

echo "Here is the URL direct to the Cloud Function"
gcloud $channel functions describe $funcname --region $region --gen2 --format="value(serviceConfig.uri)"

