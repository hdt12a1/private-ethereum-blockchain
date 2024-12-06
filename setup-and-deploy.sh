#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${GREEN}Starting Ethereum Node Setup and Deployment Process${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

# Check if geth is installed
if ! command -v geth &> /dev/null; then
    echo -e "${RED}geth is not installed. Please install geth first.${NC}"
    exit 1
fi

# Create necessary directories
mkdir -p "$SCRIPT_DIR/data"
chmod 755 "$SCRIPT_DIR/data"

# Function to get user confirmation
confirm() {
    read -r -p "${1:-Are you sure you want to proceed? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

# Display validator count information
echo -e "\n${GREEN}Validator Count Configuration:${NC}"
echo -e "The number of validators is crucial for your Ethereum network:"
echo -e "  - Each validator is a node that participates in block creation"
echo -e "  - More validators = better decentralization but slower consensus"
echo -e "  - Recommended configurations:"
echo -e "    • 3-5 validators: Good for testing and development"
echo -e "    • 5-7 validators: Suitable for small production networks"
echo -e "    • 7+ validators: Better for large production networks"
echo -e "  - Must be at least 3 for fault tolerance"
echo -e "  - Should be an odd number to prevent split votes\n"

# Prompt for validator count
while true; do
    printf "${YELLOW}Enter the number of validators to create (minimum 3): ${NC}"
    read -r VALIDATOR_COUNT
    if ! [[ "$VALIDATOR_COUNT" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Please enter a valid number${NC}"
        continue
    fi
    
    if [ "$VALIDATOR_COUNT" -lt 3 ]; then
        echo -e "${RED}Error: Validator count must be at least 3${NC}"
        continue
    fi
    
    # Warning for even numbers
    if [ $((VALIDATOR_COUNT % 2)) -eq 0 ]; then
        echo -e "${YELLOW}Warning: Using an even number of validators ($VALIDATOR_COUNT) may lead to split votes"
        echo -e "Consider using an odd number instead. Continue anyway? [y/N]: ${NC}"
        if ! confirm ""; then
            continue
        fi
    fi
    break
done

echo -e "\nSetting up ${GREEN}$VALIDATOR_COUNT${NC} validators...\n"

# Update StatefulSet replicas count
echo -e "\n${GREEN}Updating StatefulSet configuration...${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS version
    sed -i '' "s/replicas: [0-9]*/replicas: $VALIDATOR_COUNT/" "$SCRIPT_DIR/k8s/geth-statefulset.yaml"
else
    # Linux version
    sed -i "s/replicas: [0-9]*/replicas: $VALIDATOR_COUNT/" "$SCRIPT_DIR/k8s/geth-statefulset.yaml"
fi

# Export validator count for child scripts
export VALIDATOR_COUNT

# Step 1: Create accounts
echo -e "\n${YELLOW}Step 1: Creating accounts...${NC}"
bash "$SCRIPT_DIR/scripts/setup/create-accounts.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create accounts${NC}"
    exit 1
fi

# Step 2: Generate node keys
echo -e "\n${YELLOW}Step 2: Generating node keys...${NC}"
bash "$SCRIPT_DIR/scripts/setup/generate-node-keys.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to generate node keys${NC}"
    exit 1
fi

# Step 3: Create Kubernetes secrets for node keys
echo -e "\n${YELLOW}Step 3: Creating Kubernetes secrets...${NC}"
bash "$SCRIPT_DIR/scripts/k8s/create-node-keys-secret.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create node keys secret${NC}"
    exit 1
fi

# Step 4: Create ConfigMaps
echo -e "\n${YELLOW}Step 4: Creating ConfigMaps...${NC}"
bash "$SCRIPT_DIR/scripts/k8s/create-configmaps.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create ConfigMaps${NC}"
    exit 1
fi

# Step 5: Deploy to Kubernetes
echo -e "\n${YELLOW}Step 5: Deploying to Kubernetes...${NC}"
echo -e "${YELLOW}This will deploy the Ethereum nodes to your Kubernetes cluster.${NC}"
echo -e "${YELLOW}Please make sure your kubectl context is set to the correct cluster.${NC}"
echo -e "${YELLOW}Current context: $(kubectl config current-context)${NC}"

if confirm "Do you want to proceed with the Kubernetes deployment? [y/N] "; then
    bash "$SCRIPT_DIR/deploy.sh"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to deploy to Kubernetes${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Deployment cancelled by user${NC}"
    exit 0
fi

echo -e "\n${GREEN}Setup and deployment completed successfully!${NC}"
echo -e "\nYou can check the status of your deployment with:"
echo -e "${YELLOW}kubectl get pods -n ifinchain${NC}"
