#!/bin/bash
#
# Creates Python gen2 Cloud Function
#

funcname=maintgen2
entry_point=maintenance_switch
channel=beta

# enable GCP project level services
export PYTHONWARNINGS="ignore:Unverified HTTPS request"
gcloud services enable cloudfunctions.googleapis.com cloudbuild.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com run.googleapis.com artifactregistry.googleapis.com containerregistry.googleapis.com

echo "sleeping 30 seconds to stabilize..."
sleep 30

region=$(gcloud config get compute/region)
project_id=$(gcloud config get project)
[[ (-n "$region") && (-n "$project_id") ]] || { echo "ERROR could not pull region or project id"; exit 1; }

set -x

gcloud artifacts repositories create my-repo --location=$region --repository-format=docker

gcloud $channel functions deploy $funcname --entry-point=$entry_point --gen2 --runtime python310 --trigger-http --allow-unauthenticated --min-instances=1 --region=$region --set-env-vars="MAINTENANCE_MESSAGE=This is the Cloud Function maintenance message" --quiet

gcloud $channel run services update $funcname --concurrency 100 --cpu=1 --region=$region

set +x

# test curl
curl_url=$(gcloud $channel functions describe $funcname --format "value(serviceConfig.uri)" --region=$region --gen2)
echo "Cloud Function at: $curl_url"
curl $curl_url


