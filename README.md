# Ethereum Private Network on Kubernetes

This project sets up a private Ethereum network using Proof of Authority (PoA) consensus mechanism on Kubernetes. It provides a flexible setup for deploying multiple validator nodes responsible for creating and validating blocks.

## Prerequisites

- Kubernetes cluster with kubectl configured
- geth (Go Ethereum) client installed locally for key generation
- Basic understanding of Ethereum and Kubernetes concepts

## Project Structure

```
eth-static-node/
├── k8s/                            # Kubernetes manifests
│   ├── geth-node-keys-secret.yaml  # Secret for node keys and accounts
│   ├── geth-service-external.yaml  # External services (RPC/WebSocket)
│   ├── geth-statefulset.yaml      # StatefulSet for validator nodes
│   ├── geth-ingress.yaml          # Optional ingress configuration
│   ├── genesis-configmap.yaml      # Genesis block configuration
│   └── static-nodes-configmap.yaml # Static nodes configuration
├── scripts/                        # Setup and utility scripts
│   ├── setup/                      # Setup scripts
│   │   ├── create-accounts.sh      # Creates validator accounts
│   │   └── generate-node-keys.sh   # Generates node keys
│   ├── k8s/                        # Kubernetes setup scripts
│   │   ├── create-node-keys-secret.sh  # Creates K8s secrets
│   │   └── create-configmaps.sh        # Creates K8s configmaps
│   └── utils/                      # Utility scripts
├── data/                          # Directory for node data
├── setup-and-deploy.sh            # Main setup and deployment script
├── deploy.sh                      # Kubernetes deployment script
├── cleanup.sh                     # Resource cleanup script
└── README.md                      # This documentation
```

## Setup and Deployment

The project uses an interactive setup process that guides you through the deployment:

```bash
# Make the script executable
chmod +x setup-and-deploy.sh

# Run the setup and deployment script
./setup-and-deploy.sh
```

### Setup Process

1. **Prerequisites Check**
   - Verifies that geth and kubectl are installed
   - Creates necessary data directories

2. **Validator Configuration**
   - Interactive prompt for number of validators
   - Minimum requirement: 3 validators
   - Recommendations:
     - 3-5 validators: Testing/Development
     - 5-7 validators: Small Production
     - 7+ validators: Large Production
   - Warning for even numbers (potential split votes)

3. **Account Creation**
   - Creates validator accounts
   - Generates necessary keystores

4. **Node Key Generation**
   - Generates node keys for each validator
   - Creates enode URLs for P2P communication

5. **Kubernetes Resource Creation**
   - Creates secrets for node keys and accounts
   - Generates ConfigMaps for:
     - Genesis block configuration
     - Static nodes configuration

6. **Kubernetes Deployment**
   - Confirms current kubectl context
   - Deploys all Kubernetes resources
   - Option to cancel deployment if needed

## Network Parameters

- Chain ID: 1337 (configurable in genesis-configmap.yaml)
- Block Time: 15 seconds (Clique PoA)
- Gas Limit: 8,000,000
- Initial Balance: 100 ETH per validator

## Deployment Verification

After deployment completes, verify the setup:

```bash
# Check pod status
kubectl get pods -n ifinchain

# View logs for a specific node
kubectl logs -f eth-node-0 -n ifinchain

# Check node connections
kubectl exec -it eth-node-0 -n ifinchain -- geth attach \
  --exec 'admin.peers.length' http://localhost:8545
```

## Network Access

### RPC Endpoints
- HTTP RPC: http://[CLUSTER-IP]:8545
- WebSocket: ws://[CLUSTER-IP]:8546

### Using with MetaMask
1. Add a new network in MetaMask
2. Network Name: Custom PoA Network
3. RPC URL: http://[CLUSTER-IP]:8545
4. Chain ID: 1337
5. Currency Symbol: ETH

## Cleanup

To remove all deployed resources:

```bash
./cleanup.sh
```

## Troubleshooting

1. **Setup Script Issues:**
   - Check script permissions (`chmod +x setup-and-deploy.sh`)
   - Verify geth and kubectl installation
   - Ensure data directory is writable

2. **Deployment Issues:**
   - Verify kubectl context (`kubectl config current-context`)
   - Check pod logs (`kubectl logs -f eth-node-0 -n ifinchain`)
   - Verify ConfigMaps and Secrets creation

3. **Network Issues:**
   - Check node connectivity
   - Verify service endpoints
   - Ensure proper network policies

## Security Considerations

1. Node keys and accounts are stored in Kubernetes secrets
2. Interactive setup prevents accidental deployments
3. Configurable validator count for security needs
4. Option to review deployment context before proceeding
