#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the absolute path to the project root
PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
echo -e "${YELLOW}Project root: ${PROJECT_ROOT}${NC}"

# Function to check if a file exists
check_file() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "  - $file"
        return 0
    fi
    return 1
}

# Function to check if a directory exists and is not empty
check_directory() {
    local dir="$1"
    if [ -d "$dir" ] && [ -n "$(ls -A "$dir")" ]; then
        echo "  - $dir/"
        return 0
    fi
    return 1
}

# Function to remove a file if it exists
remove_file() {
    local file="$1"
    if [ -f "$file" ]; then
        rm "$file" && echo -e "${GREEN}Removed file: $file${NC}" || echo -e "${RED}Failed to remove: $file${NC}"
    else
        echo -e "${YELLOW}Skipping (does not exist): $file${NC}"
    fi
}

# Function to remove a directory if it exists
remove_directory() {
    local dir="$1"
    if [ -d "$dir" ]; then
        rm -rf "$dir" && echo -e "${GREEN}Removed directory: $dir${NC}" || echo -e "${RED}Failed to remove directory: $dir${NC}"
    else
        echo -e "${YELLOW}Skipping (does not exist): $dir${NC}"
    fi
}

echo -e "\n${RED}⚠️  WARNING: This cleanup script will remove important files${NC}"
echo -e "${YELLOW}Please read carefully what will be deleted:${NC}"

# Find all node directories
node_dirs=$(find "${PROJECT_ROOT}/data" -maxdepth 1 -type d -name "node*")
node_count=$(echo "$node_dirs" | grep -c "^")

echo -e "${BLUE}1. Node Directories (${node_count} validators):${NC}"
echo "   - Contains validator private keys"
echo "   - Contains blockchain data"
echo "   - If deleted, nodes will need to be recreated"

echo -e "\n${BLUE}2. Configuration Files:${NC}"
echo "   - password.txt: Required to unlock validator accounts"
echo "   - enode_urls.txt: Contains node connection information"

echo -e "\n${BLUE}3. Kubernetes Manifests:${NC}"
echo "   - genesis-configmap.yaml: Network genesis configuration"
echo "   - static-nodes-configmap.yaml: Node discovery configuration"
echo "   - geth-node-keys-secret.yaml: Node key secrets"

echo -e "\n${RED}⚠️  IMPORTANT:${NC}"
echo "- Deleting these files will require a complete network reset"
echo "- All blockchain data will be lost"
echo "- New validator accounts will need to be created"
echo "- Network will need to be redeployed"

echo -e "\n${YELLOW}The following files and directories will be removed:${NC}"

found_items=false

# List node directories
for dir in $node_dirs; do
    check_directory "$dir" && found_items=true
done

# List generated files
check_file "${PROJECT_ROOT}/data/enode_urls.txt" && found_items=true
check_file "${PROJECT_ROOT}/data/password.txt" && found_items=true

# List generated k8s files
check_file "${PROJECT_ROOT}/k8s/genesis-configmap.yaml" && found_items=true
check_file "${PROJECT_ROOT}/k8s/static-nodes-configmap.yaml" && found_items=true
check_file "${PROJECT_ROOT}/k8s/geth-node-keys-secret.yaml" && found_items=true

# List data directory
check_directory "${PROJECT_ROOT}/data" && found_items=true

if [ "$found_items" = false ]; then
    echo -e "${YELLOW}No files to clean up${NC}"
    exit 0
fi

# Ask for confirmation
printf "${RED}⚠️  Are you absolutely sure you want to proceed with the cleanup?${NC}\n"
printf "${RED}Type 'yes-delete-everything' to confirm: ${NC}"
read -r answer

if [ "$answer" = "yes-delete-everything" ]; then
    echo -e "\n${GREEN}Starting cleanup...${NC}"
    
    # Clean up node directories
    for dir in $node_dirs; do
        remove_directory "$dir"
    done

    # Clean up generated files
    remove_file "${PROJECT_ROOT}/data/enode_urls.txt"
    remove_file "${PROJECT_ROOT}/data/password.txt"

    # Clean up generated k8s files
    remove_file "${PROJECT_ROOT}/k8s/genesis-configmap.yaml"
    remove_file "${PROJECT_ROOT}/k8s/static-nodes-configmap.yaml"
    remove_file "${PROJECT_ROOT}/k8s/geth-node-keys-secret.yaml"

    # Clean up empty data directory
    remove_directory "${PROJECT_ROOT}/data"

    echo -e "\n${GREEN}Cleanup complete!${NC}"
else
    echo -e "${YELLOW}Cleanup cancelled${NC}"
    exit 1
fi
