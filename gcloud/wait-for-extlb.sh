#!/bin/bash

expected_http_code=200

lbname=extlb-frontend
public_ip=$(gcloud compute forwarding-rules describe $lbname --global --format="value(IPAddress)")
echo "$public_ip is the IP address of the ${lbname} Load Balancer"
[ -n "$public_ip" ] || { echo "ERROR could not lookup IP of external HTTPS LB"; exit 3; }

# no retries, timeout, allow insecure, do silent, return HTTP code
options='-k --connect-timeout 3 --retry 0 -s -o /dev/null -w %{http_code}'

delay_sec=10
tries=0
success=1
while [ $success -ne 0 ]; do
  wait_time_total=$(( tries * delay_sec ))
  echo ""
  echo "Going to try curling to public LB $public_ip ($tries attempts,wait sec total=$wait_time_total)"
  outstr=$(curl $options https://$public_ip)
  if [[ $outstr -ne $expected_http_code ]]; then
    echo "external LB at $public_ip is not ready yet ($outstr), waiting $delay_sec seconds..."
    sleep $delay_sec
  else
    echo "SUCCESS reaching public LB at $public_ip"
    curl -k https://$public_ip
    success=0 # 0=success, loop stops
  fi
  ((tries++))
done
