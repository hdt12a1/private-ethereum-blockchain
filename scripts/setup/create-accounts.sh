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

# Create directories for each node
echo -e "${YELLOW}Setting up directories for ${VALIDATOR_COUNT} validators...${NC}"
for i in $(seq 1 $VALIDATOR_COUNT); do
    mkdir -p "$SCRIPT_DIR/../../data/node$i"
done

# Function to get password from user
get_password() {
    echo -e "\n${GREEN}Password Configuration:${NC}"
    echo -e "The password will be used to:"
    echo -e "  - Encrypt validator account keys"
    echo -e "  - Sign transactions and blocks"
    echo -e "  - Protect your validator's private keys"
    echo -e "Requirements:"
    echo -e "  - Minimum 8 characters recommended"
    echo -e "  - Store it securely - cannot be recovered if lost\n"
    
    while true; do
        printf "${YELLOW}Enter password for validator accounts: ${NC}"
        read -s password
        echo
        printf "${YELLOW}Confirm password: ${NC}"
        read -s password2
        echo
        
        if [ "$password" = "$password2" ]; then
            if [ ${#password} -lt 8 ]; then
                echo -e "\n${YELLOW}Warning: Password is less than 8 characters"
                printf "Continue anyway? [y/N]: ${NC}"
                read answer
                if [ "$answer" != "y" ]; then
                    echo
                    continue
                fi
            fi
            break
        else
            echo -e "\n${RED}Error: Passwords do not match. Please try again.${NC}\n"
        fi
    done

    echo "$password" > "$SCRIPT_DIR/../../data/password.txt"
    echo -e "\n${GREEN}✓ Password saved successfully${NC}\n"
}

# Get password from user
get_password

# Generate accounts for each node
echo -e "\n${GREEN}Creating Validator Accounts${NC}"
echo -e "${YELLOW}Creating ${VALIDATOR_COUNT} validator accounts...${NC}\n"

for i in $(seq 1 $VALIDATOR_COUNT); do
    echo -e "${GREEN}Creating account for Node $i:${NC}"
    echo -e "└── Directory: data/node$i"
    echo -ne "└── Account:  "
    geth account new --datadir "$SCRIPT_DIR/../../data/node$i" --password "$SCRIPT_DIR/../../data/password.txt" 2>/dev/null | grep "Public address" | sed 's/Public address of the key://g'
done

echo -e "\n${GREEN}✓ Successfully created ${VALIDATOR_COUNT} validator accounts!${NC}"
echo -e "${YELLOW}Note: Make sure to save these addresses - they will be used in the genesis block${NC}\n"
