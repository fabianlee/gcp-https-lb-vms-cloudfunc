#!/bin/bash
#
# SSH into vm using IP addresses known by terraform
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

vm_name="$1"
if [[ -z "$vm_name" ]]; then
  echo "Usage: vmName"
  exit 1
fi

ssh_key="$(cd ..;pwd)/gcp-ssh"

# public jumpboxes (also serve as bastions for private networks)
cd vms
pub1=$(terraform output -json --state=../envs/vms.tfstate | jq ".module_public_ip.value[\"apache1-10-0-90-0\"]" -r)
pub2=$(terraform output -json --state=../envs/vms.tfstate | jq ".module_public_ip.value[\"apache2-10-0-90-0\"]" -r)
cd ..

echo "pub1/pub2 = $pub1/$pub2"

case $vm_name in

  apache1-10-0-90-0)
    set -x
    ssh ubuntu@${pub1} -i $ssh_key
    set +x
  ;;

  apache2-10-0-90-0)
    set -x
    ssh ubuntu@${pub2} -i $ssh_key
    set +x
  ;;

  *)
    echo "ERROR did not recognize that vmName $vm_name"
  ;;

esac


