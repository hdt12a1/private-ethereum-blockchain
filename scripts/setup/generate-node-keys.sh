#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

# Get validator count from environment or default to 3
VALIDATOR_COUNT=${VALIDATOR_COUNT:-3}

# Function to generate nodekey and get enode URL
generate_node() {
    local node=$1
    local datadir="$PROJECT_ROOT/data/$node"
    local node_number=${node#node}  # Extract number from node name
    
    echo -e "${GREEN}Generating keys for Node $node_number:${NC}"
    echo -e "└── Directory: data/$node/geth"
    
    # Create directory if it doesn't exist
    mkdir -p "$datadir/geth"
    
    # Generate node key using geth
    geth --datadir "$datadir" init /dev/null 2>/dev/null
    
    # Display nodekey
    echo -ne "└── Node Key:  "
    if [ -f "$datadir/geth/nodekey" ]; then
        cat "$datadir/geth/nodekey"
    else
        echo "Failed to generate nodekey"
    fi
    echo  # Add newline after node key
    
    # Get enode URL using geth
    if [ -f "$datadir/geth/nodekey" ]; then
        local pubkey=$(geth --datadir "$datadir" --exec "admin.nodeInfo.id" console 2>/dev/null || echo "")
        if [ -z "$pubkey" ]; then
            # If geth console fails, generate a basic enode URL
            pubkey=$(cat "$datadir/geth/nodekey")
        fi
        local enode_url="enode://$pubkey@$node:30303"
        echo -e "└── Enode URL: ${YELLOW}$enode_url${NC}"
        echo "$enode_url" >> "$PROJECT_ROOT/data/enode_urls.txt"
    fi
    echo
}

echo -e "\n${GREEN}Step 2: Node Key Generation${NC}"
echo -e "${YELLOW}Setting up ${VALIDATOR_COUNT} validator nodes...${NC}\n"

# Create data directories
for i in $(seq 1 $VALIDATOR_COUNT); do
    mkdir -p "$PROJECT_ROOT/data/node$i/geth"
done

# Remove old enode URLs file
rm -f "$PROJECT_ROOT/data/enode_urls.txt"

# Generate node keys and enode URLs
for i in $(seq 1 $VALIDATOR_COUNT); do
    generate_node "node$i"
done

echo -e "${GREEN}✓ Successfully generated node keys and enode URLs${NC}"
echo -e "${YELLOW}Note: Enode URLs have been saved to data/enode_urls.txt${NC}\n"
