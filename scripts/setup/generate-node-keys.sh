#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get validator count from environment or default to 3
VALIDATOR_COUNT=${VALIDATOR_COUNT:-3}

# Function to generate nodekey and get enode URL
generate_node() {
    local node=$1
    local datadir="$SCRIPT_DIR/../../data/$node"
    local node_number=${node#node}  # Extract number from node name
    
    echo -e "${GREEN}Generating keys for Node $node_number:${NC}"
    echo -e "└── Directory: data/$node/geth"
    
    # Generate nodekey
    bootnode -genkey "$datadir/geth/nodekey" 2>/dev/null
    echo -ne "└── Node Key:  "
    cat "$datadir/geth/nodekey"
    echo  # Add newline after node key
    
    # Get enode URL
    local nodekey=$(cat "$datadir/geth/nodekey")
    local enode=$(bootnode -nodekeyhex "$nodekey" -writeaddress)
    local enode_url="enode://$enode@$node:30303"
    echo -e "└── Enode URL: ${YELLOW}$enode_url${NC}"
    echo "$enode_url" >> "$SCRIPT_DIR/../../data/enode_urls.txt"
    echo
}

echo -e "\n${GREEN}Step 2: Node Key Generation${NC}"
echo -e "${YELLOW}Setting up ${VALIDATOR_COUNT} validator nodes...${NC}\n"

# Create geth directories
for i in $(seq 1 $VALIDATOR_COUNT); do
    mkdir -p "$SCRIPT_DIR/../../data/node$i/geth"
done

# Remove old enode URLs file
rm -f "$SCRIPT_DIR/../../data/enode_urls.txt"

# Generate node keys and enode URLs
for i in $(seq 1 $VALIDATOR_COUNT); do
    generate_node "node$i"
done

echo -e "${GREEN}✓ Successfully generated node keys and enode URLs${NC}"
echo -e "${YELLOW}Note: Enode URLs have been saved to data/enode_urls.txt${NC}\n"
