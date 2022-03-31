#!/bin/bash
#
# Wizard to show available actions
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

# visual marker for task
declare -A done_status

# BASH does not support multi-dimensional/complex datastructures
# 1st column = action
# 2nd column = description
menu_items=(
  "prereq","Prereq OS modules and ansible galaxy collections"
  "tfvars,Use ansible vars to populate tf/envs/all.tfvars"
  "project,Create gcp project and enable services"
  "svcaccount,Create service account for provisioning"
  "networks,Create network, subnets, and firewall"
  "cloudnat,Create Cloud NAT for public egress of private IP"
  ""
  "sshmetadata,Load ssh key into project metadata"
  "vms,Create GCP VM instances in subnets"
  "enablessh,Setup ssh config for bastions and ansible inventory"
  "ssh,SSH into GCP VMs"
  ""
  "aping","ansible ping to GCP vms"
  "apache","Install apache on GCP vm instances"
  "cloudfunc","Deploy GCP Cloud Function gen2 \(beta\)"
  "intlb","Create GCP Internal HTTPS LB"
  "extlb","Create GCP External HTTPS LB"
  ""
  "dellbs,Delete GCP HTTPS load balancers"
  "delvms,Delete VM instances"
  "delnetworks,Delete networks and Cloud NAT"
)
# hidden menu items, available for action but not shown
#  "cacert","Create local CA, key and cert"

function showMenu() {
  echo ""
  echo ""
  echo "==========================================================================="
  echo " MAIN MENU"
  echo "==========================================================================="
  echo ""
  
  for menu_item in "${menu_items[@]}"; do
    # skip empty lines
    [ -n "$menu_item" ] || { printf "\n"; continue; }

    menu_id=$(echo $menu_item | cut -d, -f1)
    # eval done so that embedded variables get evaluated (e.g. MYKUBECONFIG)
    label=$(eval echo $menu_item | cut -d, -f2-)
    printf "%-16s %-60s %-12s\n" "$menu_id" "$label" "${done_status[$menu_id]}"

  done
  echo ""
} # showMenu


GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'
NF='\033[0m'
function echoGreen() {
  echo -e "${GREEN}$1${NC}"
}
function echoRed() {
  echo -e "${RED}$1${NC}"
}
function echoYellow() {
  echo -e "${YELLOW}$1${NC}"
}

function ensure_binary() {
  binary="$1"
  install_instructions="$2"
  binpath=$(which $binary)
  if [ -z "$binpath" ]; then
    echo "ERROR you must install $binary before running this wizard"
    echo "$install_instructions"
    exit 1
  fi
}

function check_prerequisites() {

  # make sure binaries are installed 
  ensure_binary gcloud "install https://cloud.google.com/sdk/docs/install"
  ensure_binary kubectl "install https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
  ensure_binary terraform "install https://fabianlee.org/2021/05/30/terraform-installing-terraform-manually-on-ubuntu/"
  ensure_binary ansible "install https://fabianlee.org/2021/05/31/ansible-installing-the-latest-ansible-on-ubuntu/"
  ensure_binary yq "download from https://github.com/mikefarah/yq/releases"
  ensure_binary jq "run 'sudo apt install jq'"
  ensure_binary make "run 'sudo apt install make'"

  # show binary versions
  # on apt, can be upgraded with 'sudo apt install --only-upgrade google-cloud-sdk -y'
  gcloud --version | grep 'Google Cloud SDK'
  kubectl version --short 2>/dev/null
  terraform --version | head -n 1
  ansible --version | head -n1
  yq --version
  jq --version
  make --version | head -n1

  yq_major_version=$(yq --version | grep -Po "version \K\d?\.")
  if [[ $yq_major_version < "4." ]]; then
    echo "ERROR expecting yq to be at least 4.x, older versions have a different syntax"
    echo "download newer version from https://github.com/mikefarah/yq/releases"
    exit 99
  fi

  # check for gcloud login context
  gcloud projects list > /dev/null 2>&1
  [ $? -eq 0 ] || gcloud auth login --no-launch-browser
  gcloud auth list

  # create personal credentials that terraform provider can use
  gcloud auth application-default print-access-token >/dev/null 2>&1
  [ $? -eq 0 ] || gcloud auth application-default login

} # check_prerequisites


###### MAIN ###########################################


check_prerequisites "$@"

if [ -f tf/envs/all.tfvars ]; then
  source tf/envs/all.tfvars

  echo "project_id is $project_id"
  gcloud config set project $project_id
fi


# loop where user can select menu items
lastAnswer=""
answer=""
while [ 1 == 1 ]; do
  showMenu
  test -t 0
  if [ ! -z $lastAnswer ]; then echo "Last action was '${lastAnswer}'"; fi
  read -p "Which action (q to quit) ? " answer
  echo ""

  case $answer in
    prereq)
      set -x
      ansible-playbook playbooks/install_dependencies.yml -l localhost
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    tfvars)
      set -x
      ansible-playbook playbooks/create-tf-vars-local.yaml -l localhost
      retVal=$?
      set +x

      cat tf/envs/all.tfvars

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    project)
      set -x
      cd tf && make project
      retVal=$?
      set +x

      # pull out project id
      source envs/all.tfvars
      echo ""
      echo "project_id is now $project_id"
      echo "region is $region"
      echo "zone is $zone"
      cd ..

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    svcaccount)
      set -x
      cd tf && make svcaccount
      retVal=$?
      set +x
      cd ..

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    networks)
      set -x
      cd tf && make networks
      retVal=$?
      set +x
      cd ..

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    cloudnat)
      set -x
      cd tf && make cloudnat
      retVal=$?
      cd ..
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    sshmetadata)
      set -x
      gcloud/add-gcp-metadata-ssh-key.sh $project_id
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    vms)
      set -x
      cd tf && make vms
      retVal=$?
      set +x
      cd ..

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    enablessh)
      set -x
      gcloud/enable-ssh.sh $project_id $region
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    ssh)
      retVal=0
      echo "1. apache1-10-0-90-0"
      echo "2. apache2-10-0-90-0"
      echo ""
      read -p "ssh into which jumpbox ? " which_jumpbox

      case $which_jumpbox in
        1) jumpbox=apache1-10-0-90-0
        ;;
        2) jumpbox=apache2-10-0-90-0
        ;;
        *)
          echo "ERROR did not recognize which $which_jumpbox, valid choices 1-2"
          retVal=1
        ;;
      esac

      set -x
      tf/ssh-into-jumpbox-tf.sh $jumpbox
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    aping)
      set -x
      ansible -m ping all
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    apache)
      set -x
      ansible-playbook playbooks/apache-gcp.yaml -l jumpboxes_public
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    cloudfunc)
      set -x
      ansible-playbook playbooks/gcp-cloud-function.yaml -l localhost
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    cacert)
      set -x
      ansible-playbook playbooks/create-ca-cert-local.yaml -l localhost
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    intlb)
      set -x
      ansible-playbook playbooks/gcp-loadbalancer-internal.yaml -l localhost
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    extlb)
      set -x
      ansible-playbook playbooks/gcp-loadbalancer-external.yaml -l localhost
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    dellbs)
      set -x
      ansible-playbook playbooks/DELETE-gcp-loadbalancers-external.yaml -l localhost
      retVal=$?
      set +x

      set +x 
      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    delnetworks)
      set -x
      gcloud/delete-network-endpoint-groups.sh $project_id $network_name $region
      cd tf && make cloudnat-destroy && make networks-destroy
      retVal=$?
      set +x
      cd ..

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    delvms)
      set -x
      cd tf && make vms-destroy
      retVal=$?
      set +x
      cd ..

      set +x 
      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    q|quit|0)
      echo "QUITTING"
      exit 0;;
    *)
      echoRed "ERROR that is not one of the options, $answer";;
  esac

  lastAnswer=$answer
  echo "press <ENTER> to continue..."
  read -p "" foo

done




