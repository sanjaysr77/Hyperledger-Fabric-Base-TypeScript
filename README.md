# eKYC Hyperledger Fabric Network

A Hyperledger Fabric 2.5.x network for managing electronic Know Your Customer (eKYC) consent and token lifecycle. This infrastructure provides a blockchain-based solution for recording and validating customer consent with immutable audit trails.

## Prerequisites

- Docker and Docker Compose (20.10+)
- Node.js (18+) and npm
- Hyperledger Fabric CLI tools
- Git

## Quick Start

### 1. Set Up the Network

```bash
# Start the Fabric network (CA, peers, orderer, CouchDB)
./network.sh up

# Create channels
./scripts/deploy-channels.sh

# Set anchor peers
./set-anchor-peers.sh
```

### 2. Build and Deploy Chaincode

```bash
# Build the TypeScript chaincode
cd chaincode && npm install && npm run build

# Deploy all chaincodes to the network
cd .. && ./deploy-all-chaincodes.sh
```

### 3. Invoke Chaincode

```bash
# Use invoke script to test transactions
./invoke.sh
```

## Directory Structure

- `chaincode/` - eKYC smart contract (TypeScript, Fabric 2.5.x)
  - `src/kyc-contract.ts` - Main contract with consent and token management
  - `src/index.ts` - Contract exports
- `docker/` - Docker Compose configurations
  - `docker-compose-network.yaml` - Fabric nodes (peers, orderer)
  - `docker-compose-ca.yaml` - Certificate Authority
  - `docker-compose-couch.yaml` - CouchDB for state database
- `scripts/` - Network management scripts
  - `deploy-channels.sh` - Create and join channels
  - `deploy-chaincodes.sh` - Install and approve chaincodes
  - `ca-functions.sh` - Certificate Authority utilities
- `config/` - Fabric configuration (core.yaml)
- `configtx/` - Channel and organization definitions

## Chaincode: eKYC Token Contract

The smart contract manages the complete lifecycle of eKYC consent and token verification.

### Transactions

#### RecordConsent (Write)
Records a customer's consent for eKYC verification.

```bash
./invoke.sh RecordConsent consentId customerId GIVEN
```

**Parameters:**
- `consentId` - Unique identifier for the consent record
- `customerId` - Customer identifier
- `status` - Consent status (must be "GIVEN")

**Returns:** Stores consent on ledger with timestamp

#### GetConsent (Read)
Retrieves a previously recorded consent record.

```bash
./invoke.sh GetConsent consentId
```

**Parameters:**
- `consentId` - Consent record identifier

**Returns:** JSON object with consentId, customerId, status, and timestamp

### Development

Build the chaincode locally:

```bash
cd chaincode
npm install
npm run build      # Compile TypeScript to dist/
npm run dev        # Build and start chaincode
```

The contract uses Fabric Contract API decorators:
- `@Transaction()` - Endorseable transactions (writes to ledger)
- `@Transaction(false)` - Query-only transactions (reads only)

See [Fabric Chaincode Node SDK](https://hyperledger-fabric.readthedocs.io/en/latest/chaincode4ade.html#node-chaincode) for detailed API documentation.

## Scripts Reference

- `network.sh` - Main network lifecycle control (up/down/restart)
- `deploy-all-chaincodes.sh` - End-to-end chaincode deployment
- `set-anchor-peers.sh` - Configure anchor peers for gossip
- `invoke.sh` - Invoke transactions on deployed chaincodes

## Troubleshooting

**Network won't start:**
- Ensure Docker daemon is running
- Check available ports (7050, 7051, 7053, 5984, etc.)
- Clear existing containers: `docker system prune`

**Chaincode deployment fails:**
- Verify TypeScript builds: `cd chaincode && npm run build`
- Check Node.js version compatibility (18+)
- Review peer logs: `docker logs <peer-container>`

**Transaction errors:**
- Ensure channels are created: `./scripts/deploy-channels.sh`
- Verify chaincode is installed and approved
- Check consent format matches contract expectations

## License

Apache-2.0
