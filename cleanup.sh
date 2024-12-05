#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

NAMESPACE="ifinchain"

echo -e "${YELLOW}Starting cleanup of Ethereum network resources...${NC}"

# Delete resources in reverse order
echo -e "\n${GREEN}1. Deleting Ingress (if exists)${NC}"
kubectl delete ingress geth-ingress -n $NAMESPACE --ignore-not-found

echo -e "\n${GREEN}2. Deleting StatefulSet${NC}"
kubectl delete statefulset eth-node -n $NAMESPACE --ignore-not-found

echo -e "\n${GREEN}3. Deleting Services${NC}"
kubectl delete service eth-rpc -n $NAMESPACE --ignore-not-found
kubectl delete service eth-ws -n $NAMESPACE --ignore-not-found
kubectl delete service eth-node -n $NAMESPACE --ignore-not-found

echo -e "\n${GREEN}4. Deleting Secrets${NC}"
kubectl delete secret geth-node-keys -n $NAMESPACE --ignore-not-found

echo -e "\n${GREEN}5. Deleting ConfigMaps${NC}"
kubectl delete configmap eth-genesis-config -n $NAMESPACE --ignore-not-found
kubectl delete configmap eth-static-nodes -n $NAMESPACE --ignore-not-found

echo -e "\n${GREEN}6. Deleting PVCs${NC}"
kubectl delete pvc -l app=eth-node -n $NAMESPACE --ignore-not-found

echo -e "\n${YELLOW}Waiting for resources to be deleted...${NC}"
sleep 5

# Verify deletion
echo -e "\n${GREEN}Verifying resource deletion:${NC}"
kubectl get all,ing,cm,secret,pvc -l app=eth-node -n $NAMESPACE

echo -e "\n${GREEN}Cleanup completed!${NC}"
