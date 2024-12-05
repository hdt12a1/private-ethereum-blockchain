#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a resource exists
check_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    kubectl get $resource_type $resource_name -n $namespace >/dev/null 2>&1
}

# Function to wait for resource to be ready
wait_for_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    local timeout=60
    local counter=0
    
    echo -e "${YELLOW}Waiting for $resource_type/$resource_name to be ready...${NC}"
    while ! check_resource $resource_type $resource_name $namespace; do
        sleep 2
        counter=$((counter + 2))
        if [ $counter -ge $timeout ]; then
            echo -e "${RED}Timeout waiting for $resource_type/$resource_name${NC}"
            exit 1
        fi
    done
    echo -e "${GREEN}$resource_type/$resource_name is ready${NC}"
}

# Function to check if namespace exists, create if it doesn't
ensure_namespace() {
    local namespace=$1
    if ! kubectl get namespace $namespace >/dev/null 2>&1; then
        echo -e "${YELLOW}Creating namespace $namespace${NC}"
        kubectl create namespace $namespace
        wait_for_resource "namespace" $namespace ""
    else
        echo -e "${GREEN}Namespace $namespace already exists${NC}"
    fi
}

# Function to deploy a resource and wait for it
deploy_resource() {
    local file=$1
    local resource_type=$2
    local resource_name=$3
    local namespace=$4

    echo -e "${YELLOW}Deploying $resource_type/$resource_name${NC}"
    kubectl apply -f $file -n $namespace
    wait_for_resource $resource_type $resource_name $namespace
}

# Main deployment script
echo -e "${GREEN}Starting deployment process...${NC}"

# 1. Create namespace
ensure_namespace "ifinchain"

# 2. Deploy ConfigMaps (Genesis and Static Nodes configurations)
echo -e "\n${GREEN}Step 1: Deploying ConfigMaps${NC}"
deploy_resource "k8s/genesis-configmap.yaml" "configmap" "eth-genesis-config" "ifinchain"
deploy_resource "k8s/static-nodes-configmap.yaml" "configmap" "eth-static-nodes" "ifinchain"

# 3. Deploy Secret (Node keys and accounts)
echo -e "\n${GREEN}Step 2: Deploying Secrets${NC}"
deploy_resource "k8s/geth-node-keys-secret.yaml" "secret" "geth-node-keys" "ifinchain"

# 4. Deploy Services
echo -e "\n${GREEN}Step 3: Deploying Services${NC}"
deploy_resource "k8s/geth-service-external.yaml" "service" "eth-node" "ifinchain"

# 5. Deploy StatefulSet
echo -e "\n${GREEN}Step 4: Deploying StatefulSet${NC}"
deploy_resource "k8s/geth-statefulset.yaml" "statefulset" "eth-node" "ifinchain"

# Wait for all pods to be ready
echo -e "\n${YELLOW}Waiting for all pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=eth-node -n ifinchain --timeout=300s

# 6. Deploy Ingress
if [ -f "k8s/geth-ingress.yaml" ]; then
    echo -e "\n${GREEN}Step 5: Deploying Ingress${NC}"
    deploy_resource "k8s/geth-ingress.yaml" "ingress" "geth-ingress" "ifinchain"
fi

echo -e "\n${GREEN}Deployment completed successfully!${NC}"
echo -e "\nYou can check the status of your nodes with:"
echo -e "${YELLOW}kubectl get pods -n ifinchain${NC}"
echo -e "\nTo check the logs of a specific node:"
echo -e "${YELLOW}kubectl logs -f eth-node-0 -n ifinchain${NC}"
echo -e "\nTo check if nodes are connected:"
echo -e "${YELLOW}kubectl exec -it eth-node-0 -n ifinchain -- geth attach --exec 'admin.peers.length' http://localhost:8545${NC}"
