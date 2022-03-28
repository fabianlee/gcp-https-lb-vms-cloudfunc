#!/bin/bash
#
# Shows public IP for VMs, and bastion configs
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

project_id="$1"
region="$2"
if [[ -z "$project_id" || -z "$region" ]]; then
  echo "Usage: projectId region"
  exit 1
fi


gcloud config set project $project_id

export pub1=$(gcloud compute instances describe apache1-10-0-90-0 --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --zone=$region-b)
export pub2=$(gcloud compute instances describe apache2-10-0-90-0 --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --zone=$region-c)

ssh_key="$(cd ..;pwd)/gcp-ssh"

# remove any saved ssh thumbprints from previous builds
ssh-keygen -f ~/.ssh/known_hosts -R $pub1 2>/dev/null
ssh-keygen -f ~/.ssh/known_hosts -R $pub2 2>/dev/null

echo ""
echo "Writing ansible_inventory.ini configured for jumpbox and bastion usage"
cat ../ansible_inventory.ini.template | envsubst > ../ansible_inventory.ini

cat <<EOL

==============================
ssh into public apache1-10-0-90-0
  ssh ubuntu@${pub1} -i $ssh_key

ssh into public apache2-10-0-91-0
  ssh ubuntu@${pub2} -i $ssh_key
==============================
EOL



