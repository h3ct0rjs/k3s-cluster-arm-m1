#!/bin/bash
#TODO: Do a quick overview of the following items: DRY, what I want to achieve with this, check status of cluster
#Add arguments to the bash scripts
RED="31"
GREEN="32"
YELLOW="33"
BLUE="34"
BOLDGREEN="\e[1;${GREEN}m"
BOLDYELLOW="\e[1;${YELLOW}m"
BOLDRED="\e[1;${RED}m"
BOLDBLUE="\e[1;${BLUE}m"
ENDCOLOR="\e[0m"

install_dep(){
  printf "${BOLDYELLOW}\n[INFO]Validating dependencies${ENDCOLOR}"
  if ! command -v brew &> /dev/null
  then
    printf "\n${BOLDRED}[ERROR]Package Manager *Brew* could not be found, install it from here https://brew.sh/"
    exit
  fi

  if command -v multipass &> /dev/null
  then
    printf "${BOLDGREEN}\n[INFO]Dependecy is ready...continuing\n${ENDCOLOR}"
  else
    printf  "${BOLDGREEN}\n[OK]Installing multipass Canonical tool \n${ENDCOLOR}"
    brew install --cask multipass
  fi
  printf  "${BOLDGREEN}"
  multipass version 
  printf  "${ENDCOLOR}"
}

cluster_create(){
  NUM_NODES=$1
  UBUNTU_VER="22.04"
  printf "${BOLDYELLOW}\n[INFO]Creating k3s Master Node${ENDCOLOR}"
  multipass launch -c 1 -m 2G -d 4G -n k3s-master $UBUNTU_VER --cloud-init ./cloud-init.yaml
  printf "${BOLDYELLOW}\n[INFO]Installing k3 on Master Node${ENDCOLOR}"
  multipass exec k3s-master -- bash -c "curl -sfL https://get.k3s.io | sh -"
  TOKEN=$(multipass exec k3s-master sudo cat /var/lib/rancher/k3s/server/node-token)
  IP=$(multipass info k3s-master | grep IPv4 | awk '{print $2}')
  printf "${BOLDYELLOW}\n[INFO]More info on k3s https://k3s.io/ ${ENDCOLOR}"
  printf "${BOLDGREEN}\n[OK]${ENDCOLOR}Master Node is completed setup: ${BOLDGREEN} $IP ${ENDCOLOR}"
  printf "${BOLDGREEN}\n[OK]${ENDCOLOR}Your k3s Token is : ${BOLDGREEN} $TOKEN ${ENDCOLOR}"

  printf "${BOLDYELLOW}\n[INFO]Creating k3s Worker Nodes${ENDCOLOR}"
  for f in $(seq 1 $NUM_NODES); do
    multipass launch -c 1 -m 1G -d 4G -n k3s-worker-$f $UBUNTU_VER --cloud-init ./cloud-init.yaml
  done

  for f in $(seq 1 $NUM_NODES); do
      printf "${BOLDYELLOW}\n[INFO]Installing k3s and Registering with Master Node: $IP Machine worker-$f${ENDCOLOR} \n"
      multipass exec k3s-worker-$f -- bash -c "curl -sfL https://get.k3s.io | K3S_URL=\"https://$IP:6443\" K3S_TOKEN=\"$TOKEN\" sh -"
  done
  printf "${BOLDGREEN}\n[OK]Summary:"
  multipass exec k3s-master -- sudo bash kubectl get nodes
  printf "${BOLDGREEN}\n[OK]Giving you a shell on Master Node${ENDCOLOR}"
  multipass exec k3s-master -- bash
}

cluster_purge(){
  cluster_status stop
  printf "${BOLDYELLOW}\n[INFO]Purging Cluster\n"
  read -p "[INFO]Are you sure about Removing the Cluster:   " yn
  case $yn in
      [Yy]* ) 
        echo "Yes removing it"; 
        
        N=( $(multipass list |grep "k3s-"|awk '{print $1}') )
        printf ${N}
        for i in ${N[@]}; do
          printf "${BOLDRED}\n[INFO]${action}ing $i ${ENDCOLOR}"
          multipass delete $i
        done
        multipass purge
        printf "${BOLDGREEN}\n[OK]${ENDCOLOR}Cluster has been PURGED\n"
        exit;;
      [Nn]* ) exit;;
      * ) printf "Please answer yes or no.";;
  esac

}

cluster_status(){
  action=$1
  MEMBERS=( $(multipass list |grep "k3s-"|awk '{print $1}') )
  printf "${BOLDYELLOW}\n[INFO]${action}ing k3s Cluster ${ENDCOLOR}"
  for i in ${MEMBERS[@]}; do
    printf "${BOLDRED}\n[INFO]${action}ing $i ${ENDCOLOR}"
    multipass $action $i
  done 

  printf "${BOLDYELLOW}\n[INFO]Cluster has been ${action}ed $i ${ENDCOLOR}\n"

  multipass list  
}

main(){
printf "\n┌─┐┬─┐┌┬┐   ┌─┐┬  ┬ ┬┌─┐┌┬┐┌─┐┬─┐\n├─┤├┬┘│││───│  │  │ │└─┐ │ ├┤ ├┬┘\n┴ ┴┴└─┴ ┴   └─┘┴─┘└─┘└─┘ ┴ └─┘┴└─\n"
printf "${BOLDBLUE}\n[INFO]${ENDCOLOR}Please select a valid option:"
printf "${BOLDBLUE}\n[1]${ENDCOLOR} Create k3s Cluster "
printf "${BOLDBLUE}\n[2]${ENDCOLOR} Stop k3s Cluster"
printf "${BOLDBLUE}\n[3]${ENDCOLOR} Start k3s Cluster"
printf "${BOLDBLUE}\n[4]${ENDCOLOR} Purge k3s Cluster"
while true; do
  read -p "Enter your choice: >" choice
  case $choice in
  1)
    install_dep
    read -p "Insert the Number of K3S Nodes" nn
    cluster_create $nn
    ;;
  2)
    cluster_status stop
    ;;
  3)
    cluster_status start
    ;;
  4)
    cluster_purge
    ;;
  *)
    printf "${BOLDRED}\n[*] Invalid choice. Please try again!!."
    ;;
  esac
done
}

main 