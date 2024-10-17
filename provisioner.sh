#!/bin/bash
#feedback: @h3ct0rjs

# Define color codes and styles
RED="31"
GREEN="32"
YELLOW="33"
BLUE="34"
BOLDGREEN="\e[1;${GREEN}m"
BOLDYELLOW="\e[1;${YELLOW}m"
BOLDRED="\e[1;${RED}m"
BOLDBLUE="\e[1;${BLUE}m"
ENDCOLOR="\e[0m"

# Function to install dependencies
install_dep() {
  printf "${BOLDYELLOW}\n[INFO] Validating dependencies${ENDCOLOR}"

  # Check if Homebrew is installed
  if ! command -v brew &> /dev/null; then
    printf "\n${BOLDRED}[ERROR] Package Manager *Brew* could not be found, install it from here https://brew.sh/${ENDCOLOR}"
    exit 1
  fi

  # Check if Multipass is installed
  if command -v multipass &> /dev/null; then
    printf "${BOLDGREEN}\n[INFO] Dependency is ready...continuing\n${ENDCOLOR}"
  else
    printf "${BOLDGREEN}\n[OK] Installing multipass Canonical tool\n${ENDCOLOR}"
    brew install --cask multipass
  fi

  # Display Multipass version
  printf "${BOLDGREEN}"
  multipass version
  printf "${ENDCOLOR}"
}

# Function to create a k3s cluster
cluster_create() {
  NUM_NODES=$1
  UBUNTU_VER="24.04"
  MASTER_NAME="k3s-master"

  printf "${BOLDYELLOW}\n[INFO] Creating k3s Master Node${ENDCOLOR}"
  multipass launch -c 2 -m 4G -d 10G -n $MASTER_NAME $UBUNTU_VER --cloud-init ./cloud-init.yaml

  printf "${BOLDYELLOW}\n[INFO] Installing k3 on Master Node${ENDCOLOR}"
  multipass exec $MASTER_NAME -- bash -c "curl -sfL https://get.k3s.io | sh -"

  # Retrieve k3s token and IP address
  TOKEN=$(multipass exec $MASTER_NAME sudo cat /var/lib/rancher/k3s/server/node-token)
  IP=$(multipass info $MASTER_NAME | grep IPv4 | awk '{print $2}')

  printf "${BOLDYELLOW}\n[INFO] More info on k3s https://k3s.io/${ENDCOLOR}\n"
  printf "${BOLDGREEN}\n[OK] Master Node is completed setup: ${BOLDGREEN} $IP ${ENDCOLOR} \n"
  printf "${BOLDGREEN}\n[OK] Your k3s Token is: ${BOLDGREEN} $TOKEN ${ENDCOLOR}\n"

  printf "${BOLDYELLOW}\n[INFO] Creating k3s Worker Nodes${ENDCOLOR}\n"
  for f in $(seq 1 $NUM_NODES); do
    multipass launch -c 1 -m 2G -d 8G -n k3s-worker-$f $UBUNTU_VER --cloud-init ./cloud-init.yaml
  done

  for f in $(seq 1 $NUM_NODES); do
    printf "${BOLDYELLOW}\n[INFO] Installing k3s and Registering with Master Node: $IP Machine worker-$f${ENDCOLOR}\n"
    multipass exec k3s-worker-$f -- bash -c "curl -sfL https://get.k3s.io | K3S_URL=\"https://$IP:6443\" K3S_TOKEN=\"$TOKEN\" sh -"
  done

  printf "${BOLDGREEN}\n[OK] Summary:${ENDCOLOR}\n"
  multipass exec $MASTER_NAME -- sudo bash -c "kubectl get nodes"

  # Attempt to mount the local directory to the k3s-master node
  LOCAL_DIR="/Users/hjimenez/Tmp/Linux/"
  printf "${BOLDGREEN}\n[OK] Mounting a Working directory in ${LOCAL_DIR} ${ENDCOLOR} \n"
  echo "$LOCAL_DIR $MASTER_NAME/k3s/"
  if ! multipass mount $LOCAL_DIR $MASTER_NAME:/home/ubuntu/k3s/; then
    printf "${BOLDRED}\n[ERROR] Failed to mount $LOCAL_DIR to $MASTER_NAME/k3s/ ${ENDCOLOR}\n"
    exit 1
  fi

  printf "${BOLDGREEN}\n[OK] Transfering the Kubeconfig file to local folder ${ENDCOLOR} \n"
  CONFIG_FILE="/home/ubuntu/k3s/kubeconfig.yaml"
  NEW_CLUSTER_NAME="k3s-local-cluster"
  multipass exec $MASTER_NAME -- sudo chmod 666 /etc/rancher/k3s/k3s.yaml   # This is an experimental lab,
                                                                            # disposable avoid this if you're in a non-trust environment.
  multipass exec $MASTER_NAME -- sudo cp /etc/rancher/k3s/k3s.yaml $CONFIG_FILE
  # Replace the server IP
  multipass exec $MASTER_NAME -- sed -i.bak "s|server: https://.*:6443|server: https://$IP:6443|g" $CONFIG_FILE

  # Replace the cluster name
  multipass exec $MASTER_NAME -- sed -i.bak "s|name: default|name: $NEW_CLUSTER_NAME|g" $CONFIG_FILE
  multipass exec $MASTER_NAME -- sed -i.bak "s|cluster: default|cluster: $NEW_CLUSTER_NAME|g" $CONFIG_FILE
  multipass exec $MASTER_NAME -- sed -i.bak "s|context: default|context: $NEW_CLUSTER_NAME|g" $CONFIG_FILE

  # Remove the backup file created by sed
  rm ${CONFIG_FILE}.bak
  #multipass exec $MASTER_NAME -- sudo chmod 666 /home/ubuntu/kubeconfig.yaml

  multipass info $MASTER_NAME
  multipass list

  printf "${BOLDGREEN}\n[OK]Complete Please execute ${ENDCOLOR} \n"
  printf "${BOLDGREEN}\n[OK]multipass exec ${MASTER_NAME} -- shell ${ENDCOLOR} to get access or
  use the kubeconfig file located in ${LOCAL_DIR}/kubeconfig.yaml \n"

}

# Function to purge the cluster
cluster_purge() {
  cluster_status stop
  printf "${BOLDYELLOW}\n[INFO] Purging Cluster${ENDCOLOR}"

  read -p "[INFO] Are you sure about Removing the Cluster? (y/n): " yn
  case $yn in
    [Yy]* )
      echo "Yes, removing it."
      N=( $(multipass list | grep "k3s-" | awk '{print $1}') )
      for i in ${N[@]}; do
        printf "${BOLDRED}\n[INFO] Deleting $i ${ENDCOLOR}"
        multipass delete $i
      done
      multipass purge
      printf "${BOLDGREEN}\n[OK] Cluster has been PURGED${ENDCOLOR}\n"
      exit 0
      ;;
    [Nn]* ) exit 0 ;;
    * ) printf "Please answer yes or no." ;;
  esac
}

# Function to manage cluster status
cluster_status() {
  action=$1
  MEMBERS=( $(multipass list | grep "k3s-" | awk '{print $1}') )

  if [ ${#MEMBERS[@]} -eq 0 ]; then
    printf "${BOLDRED}\n[ERROR] No k3s cluster members found.Create a cluster with the script.\n Exiting.${ENDCOLOR}\n"
    exit 1
  fi

  printf "${BOLDYELLOW}\n[INFO] ${action}ing k3s Cluster${ENDCOLOR}"
  for i in ${MEMBERS[@]}; do
    printf "${BOLDRED}\n[INFO] ${action}ing $i ${ENDCOLOR}"
    multipass $action $i
  done

  printf "${BOLDYELLOW}\n[INFO] Cluster has been ${action}ed${ENDCOLOR}\n"
  multipass list
}

menu() {
  printf "\n┌─┐┬─┐┌┬┐   ┌─┐┬  ┬ ┬┌─┐┌┬┐┌─┐┬─┐\n├─┤├┬┘│││───│  │  │ │└─┐ │ ├┤ ├┬┘\n┴ ┴┴└─┴ ┴   └─┘┴─┘└─┘└─┘ ┴ └─┘┴└─\n"
  printf "${BOLDBLUE}\n[INFO]${ENDCOLOR}Please select a valid option:"
  printf "${BOLDBLUE}\n[1]${ENDCOLOR} Create k3s Cluster "
  printf "${BOLDBLUE}\n[2]${ENDCOLOR} Stop k3s Cluster"
  printf "${BOLDBLUE}\n[3]${ENDCOLOR} Start k3s Cluster"
  printf "${BOLDBLUE}\n[4]${ENDCOLOR} Purge k3s Cluster"
  printf "${BOLDBLUE}\n[5]${ENDCOLOR} Exit\n"
}

main(){
  menu
  while true; do
    read -p "Enter your choice: >" choice
    case $choice in
    1)
      install_dep
      read -p "Insert the Number of K3S Nodes> " nn
      cluster_create $nn
      exit 0
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
    5)
      exit 0
      ;;
    *)
      printf "${BOLDRED}\n[*] Invalid choice. Please try again!!."
      sleep 3
      clear
      menu
      ;;
    esac
  done
}

main