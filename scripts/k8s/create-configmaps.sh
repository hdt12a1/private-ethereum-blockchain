#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function to prompt for validator count
prompt_validator_count() {
    local default=$1
    local value

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

    while true; do
        printf "${YELLOW}Enter number of validators (default: %s): ${NC}" "$default" >&2
        read value
        
        # Use default if empty
        value="${value:-$default}"
        
        # Validate numeric input
        if ! [[ "$value" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Error: Validator count must be a number${NC}" >&2
            continue
        fi
        
        # Validate minimum value
        if [ "$value" -lt 3 ]; then
            echo -e "${RED}Error: Validator count must be at least 3${NC}" >&2
            continue
        fi

        # Warning for even numbers
        if [ $((value % 2)) -eq 0 ]; then
            echo -e "${YELLOW}Warning: Using an even number of validators ($value) may lead to split votes${NC}" >&2
            echo -e "${YELLOW}Consider using an odd number instead. Continue anyway? [y/N]: ${NC}" >&2
            read confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        
        printf "%s" "$value"
        break
    done
}

# Get validator count from environment or prompt
if [ -z "${VALIDATOR_COUNT}" ]; then
    VALIDATOR_COUNT=$(prompt_validator_count "3")
fi

# Create k8s directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/../../k8s"

# Function to extract addresses from keystore files
get_validator_addresses() {
    local -a address_array=()
    
    for i in $(seq 1 $VALIDATOR_COUNT); do
        local node="node$i"
        local keystore_dir="$SCRIPT_DIR/../../data/$node/keystore"
        
        # Check if keystore directory exists
        if [ ! -d "$keystore_dir" ]; then
            echo -e "${RED}Keystore directory not found: $keystore_dir${NC}" >&2
            exit 1
        fi
        
        # Find the keystore file
        local keystore_file=$(ls "$keystore_dir/"*)
        if [ ! -f "$keystore_file" ]; then
            echo -e "${RED}Keystore file not found in: $keystore_dir${NC}" >&2
            exit 1
        fi
        
        # Check file permissions
        if [ ! -r "$keystore_file" ]; then
            echo -e "${YELLOW}Fixing permissions for: $keystore_file${NC}" >&2
            chmod 644 "$keystore_file"
        fi
        
        # Extract address from the JSON file
        local address=$(grep -o '"address":"[^"]*"' "$keystore_file" | cut -d'"' -f4)
        if [ -z "$address" ]; then
            echo -e "${RED}Failed to extract address from $keystore_file${NC}" >&2
            exit 1
        fi
        
        # Store address in array
        address_array+=("$address")
        echo -e "Node $i address: 0x$address" >&2
    done
    
    # Print addresses in array format for bash
    printf '%s\n' "${address_array[@]}"
}

# Function to prompt for input with default value
prompt_with_default() {
    local prompt=$1
    local default=$2
    local name=$3
    local value

    while true; do
        # Print prompt with default value
        printf "${YELLOW}%s (default: %s): ${NC}" "$prompt" "$default" >&2
        read value
        
        # Use default if empty
        value="${value:-$default}"
        
        # Validate numeric input
        if ! [[ "$value" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Error: ${name} must be a number${NC}" >&2
            continue
        fi
        
        printf "%s" "$value"
        break
    done
}

# Function to validate numeric input
validate_numeric() {
    local value=$1
    local name=$2
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: ${name} must be a number${NC}" >&2
        exit 1
    fi
}

# Function to create genesis config
create_genesis_config() {
    local -a addresses=("$@")
    
    # Create alloc JSON dynamically with proper formatting
    local alloc_json=""
    for ((i=0; i<${#addresses[@]}; i++)); do
        if [ $i -gt 0 ]; then
            alloc_json="${alloc_json},"
        fi
        alloc_json="${alloc_json}
        \"0x${addresses[$i]}\": {
            \"balance\": \"${INITIAL_BALANCE_WEI}\"
        }"
    done

    # Create extradata with proper format for Clique PoA:
    # 32 bytes of zeros + concatenated validator addresses + 65 bytes of zeros + vanity (if any)
    local vanity="0000000000000000000000000000000000000000000000000000000000000000"
    local validators=""
    for addr in "${addresses[@]}"; do
        validators="${validators}${addr}"
    done
    local seal="0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    local extradata="0x${vanity}${validators}${seal}"
    
    echo -e "${GREEN}Creating genesis configmap...${NC}" >&2
    
    cat > "$SCRIPT_DIR/../../k8s/genesis-configmap.yaml" << EOF
# This file is auto-generated by create-configmaps.sh
# DO NOT EDIT THIS FILE DIRECTLY
# Last generated: $(date)
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: geth-genesis-config
  namespace: ${NAMESPACE}
data:
  genesis.json: |
    {
      "config": {
        "chainId": ${CHAIN_ID},
        "homesteadBlock": 0,
        "eip150Block": 0,
        "eip155Block": 0,
        "eip158Block": 0,
        "byzantiumBlock": 0,
        "constantinopleBlock": 0,
        "petersburgBlock": 0,
        "istanbulBlock": 0,
        "berlinBlock": 0,
        "clique": {
          "period": ${CLIQUE_PERIOD},
          "epoch": ${CLIQUE_EPOCH}
        }
      },
      "difficulty": "${DIFFICULTY}",
      "gasLimit": "${GAS_LIMIT}",
      "extradata": "${extradata}",
      "alloc": {${alloc_json}
      }
    }
EOF

    echo -e "${GREEN}Created genesis configmap 'geth-genesis-config' in namespace '${NAMESPACE}'${NC}"
}

# Function to update namespace in a YAML file
update_namespace_in_file() {
    local file=$1
    local namespace=$2
    
    # Use sed to replace namespace line, handling both 'namespace: value' and empty 'namespace: '
    sed -i '' "s/^[[:space:]]*namespace:.*$/  namespace: ${namespace}/" "$file"
}

# Function to update namespace in all manifest files
update_all_manifests() {
    local namespace=$1
    local k8s_dir="$SCRIPT_DIR/../../k8s"
    
    # Update namespace in all YAML files
    for file in "$k8s_dir"/*.yaml; do
        if [ -f "$file" ]; then
            update_namespace_in_file "$file" "$namespace"
            echo -e "${GREEN}Updated namespace to '${namespace}' in $(basename "$file")${NC}"
        fi
    done
}

# Function to create static nodes config
create_static_nodes_config() {
    echo -e "${GREEN}Creating static nodes configmap...${NC}" >&2
    
    # Prompt for namespace with detailed explanation
    echo -e "\n${GREEN}Namespace Configuration:${NC}"
    echo -e "The namespace is crucial for your Kubernetes deployment:"
    echo -e "  - All resources will be created in this namespace"
    echo -e "  - Static nodes will use this namespace for service discovery"
    echo -e "  - Make sure this matches the namespace where your nodes will be deployed"
    
    echo -e "\n${GREEN}Node Discovery Example:${NC}"
    echo -e "When using headless services for static nodes:"
    echo -e "1. Each node gets a DNS entry in this format:"
    echo -e "   ${YELLOW}<pod-name>.<service-name>.<namespace>.svc.cluster.local${NC}"
    echo -e "   Example: ${YELLOW}geth-node-0.geth-node.ethereum.svc.cluster.local${NC}"
    echo -e ""
    echo -e "2. Enode URL format in static-nodes.json:"
    echo -e "   ${YELLOW}enode://<node-key>@<service-name>.<namespace>.svc.cluster.local:30303${NC}"
    echo -e "   Example: ${YELLOW}enode://8f4e444...@geth-node-0.geth-node.ethereum.svc.cluster.local:30303${NC}"
    echo -e ""
    echo -e "3. Kubernetes service configuration example:"
    echo -e "   ${YELLOW}apiVersion: v1"
    echo -e "   kind: Service"
    echo -e "   metadata:"
    echo -e "     name: geth-node"
    echo -e "     namespace: ethereum"
    echo -e "   spec:"
    echo -e "     clusterIP: None  # This makes it a headless service"
    echo -e "     selector:"
    echo -e "       app: geth"
    echo -e "     ports:"
    echo -e "     - port: 30303"
    echo -e "       name: discovery${NC}"
    echo -e ""
    echo -e "This setup enables:"
    echo -e "  • Stable network identity for each pod"
    echo -e "  • Automatic DNS-based discovery"
    echo -e "  • Direct pod-to-pod communication\n"
    
    printf "${YELLOW}Enter the namespace for deployment (default: default): ${NC}"
    read NAMESPACE
    NAMESPACE=${NAMESPACE:-default}
    
    # Update namespace in all manifest files
    update_all_manifests "$NAMESPACE"
    
    # Read enode URLs and format them properly
    local enode_urls=()
    while IFS= read -r url; do
        if [ ! -z "$url" ]; then
            # Replace node names with StatefulSet pod DNS names
            # From: @nodeX -> @geth-node-X.geth-node.namespace.svc.cluster.local
            url=$(echo "$url" | sed -E "s/@node([0-9]+)/@geth-node-\1.geth-node.${NAMESPACE}.svc.cluster.local/")
            enode_urls+=("$url")
        fi
    done < "$SCRIPT_DIR/../../data/enode_urls.txt"
    
    # Create the static nodes JSON with proper formatting
    local nodes_json=""
    for i in "${!enode_urls[@]}"; do
        if [ $i -gt 0 ]; then
            nodes_json="${nodes_json},\n"
        fi
        nodes_json="${nodes_json}      \"${enode_urls[$i]}\""
    done
    
    cat > "$SCRIPT_DIR/../../k8s/static-nodes-configmap.yaml" << EOF
# This file is auto-generated by create-configmaps.sh
# DO NOT EDIT THIS FILE DIRECTLY
# Last generated: $(date)
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: geth-static-nodes
  namespace: ${NAMESPACE}
data:
  static-nodes.json: |
    [
$(echo -e "$nodes_json")
    ]
EOF

    echo -e "${GREEN}Created static nodes configmap 'geth-static-nodes' in namespace '${NAMESPACE}'${NC}"
    echo -e "${YELLOW}Note: Make sure you have a StatefulSet named 'geth-node' and a headless service named 'geth-node' in namespace '${NAMESPACE}'${NC}"
    echo -e "${YELLOW}Example node DNS: geth-node-0.geth-node.${NAMESPACE}.svc.cluster.local${NC}\n"
}

echo -e "${GREEN}Step 4: Creating ConfigMaps...${NC}"
echo -e "${GREEN}Please enter the following genesis parameters:${NC}"
echo -e "${YELLOW}Note: Press Enter to accept the default value${NC}\n"

echo -e "Chain ID:"
echo -e "  - A unique identifier for your Ethereum network"
echo -e "  - Use 1 for mainnet, 1337 is commonly used for private networks"
echo -e "  - Must be a positive integer"
CHAIN_ID=$(prompt_with_default "Enter Chain ID" "1337" "Chain ID")
echo ""

echo -e "Clique Period:"
echo -e "  - The number of seconds between blocks in the Clique consensus"
echo -e "  - Lower values mean faster blocks but more network overhead"
echo -e "  - Recommended: 5-15 seconds for testing, 15+ for production"
CLIQUE_PERIOD=$(prompt_with_default "Enter Clique period (seconds)" "5" "Clique period")
echo ""

echo -e "Clique Epoch:"
echo -e "  - Number of blocks after which to reset votes and checkpoints"
echo -e "  - Higher values mean more stable consensus but slower recovery from issues"
echo -e "  - Recommended: 30000 blocks"
CLIQUE_EPOCH=$(prompt_with_default "Enter Clique epoch (blocks)" "30000" "Clique epoch")
echo ""

echo -e "Difficulty:"
echo -e "  - The initial mining difficulty"
echo -e "  - For Clique networks, this is typically set to 1"
echo -e "  - Must be a positive integer"
DIFFICULTY=$(prompt_with_default "Enter Difficulty" "1" "Difficulty")
echo ""

echo -e "Gas Limit:"
echo -e "  - Maximum amount of gas that can be used per block"
echo -e "  - Higher values allow more transactions per block"
echo -e "  - Recommended: 8000000 for testing, adjust based on network needs"
GAS_LIMIT=$(prompt_with_default "Enter Gas limit" "8000000" "Gas limit")
echo ""

echo -e "Initial Balance:"
echo -e "  - Amount of Ether to pre-fund each validator account"
echo -e "  - This balance is allocated in the genesis block"
echo -e "  - Enter the amount in whole Ether (will be converted to Wei)"
INITIAL_BALANCE=$(prompt_with_default "Enter Initial balance (in Ether)" "100" "Initial balance")
# Convert Ether to Wei (1 Ether = 10^18 Wei)
INITIAL_BALANCE_WEI=$(echo "${INITIAL_BALANCE}000000000000000000")
echo ""

echo -e "${GREEN}Getting validator addresses...${NC}"
echo -e "Validator Addresses:"

# Get validator addresses as an array
mapfile -t VALIDATOR_ADDRESSES < <(get_validator_addresses)

# Read password from file
password=$(cat "$SCRIPT_DIR/../../data/password.txt")
echo -e "Using existing password from password.txt"

# Create genesis config with array
echo -e "Creating genesis config..."
create_genesis_config "${VALIDATOR_ADDRESSES[@]}"

# Create static nodes config
echo -e "Creating static nodes config..."
create_static_nodes_config

echo -e "${GREEN}ConfigMaps created successfully!${NC}"
echo "You can find them in:"
echo "- $(echo "$SCRIPT_DIR/../../k8s/genesis-configmap.yaml" | sed 's|/scripts/k8s/\.\./\.\./|/|')"
echo "- $(echo "$SCRIPT_DIR/../../k8s/static-nodes-configmap.yaml" | sed 's|/scripts/k8s/\.\./\.\./|/|')"
