#!/bin/bash
#
# Deletes GCP HTTPS LB components, internal and external
#

funcname=hellogen2
channel=beta
region=us-east1
location_flag="--global"

gcloud compute forwarding-rules delete ${funcname}-frontend $location_flag --quiet
gcloud compute target-https-proxies delete ${funcname}-https-proxy $location_flag --quiet
gcloud compute url-maps delete ${funcname}-lb1 $location_flag --quiet
gcloud compute backend-services delete ${funcname}-backend $location_flag --quiet
echo "there are no health-checks for serverless neg"
gcloud compute ssl-certificates delete ${funcname}-lbcert $location_flag --quiet
gcloud compute network-endpoint-groups delete ${funcname}-neg --region=$region --quiet

# need to specify gen2
gcloud $channel functions delete ${funcname} --region=$region --gen2 --quiet



