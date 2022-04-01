#!/bin/bash

funcname=maintgen2
channel=beta
region=us-east1

url=$(gcloud $channel functions describe $funcname --region $region --gen2 --format="value(serviceConfig.uri)")

hey_bin=$(which hey)
if [ -z "$hey_bin" ]; then
  sudo apt install hey -y
fi

hey -n 200 -c 20 $url
