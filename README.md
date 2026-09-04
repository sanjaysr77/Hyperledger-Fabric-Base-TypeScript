# Hyperledger Fabric Network

Infrastructure for Hyperledger Fabric 2.5.x network deployment.

## Directory Structure

- `docker/` - Docker Compose files for CA, CouchDB, and network nodes
- `scripts/` - Network initialization and deployment scripts
- `config/` - Fabric core configuration
- `configtx/` - Channel configuration

## Chaincode

Smart contracts are located in `chaincode/src/` (TypeScript) and built with the Fabric Chaincode Node SDK.

### Build & Deploy

From the project root directory:

```bash
# Build TS chaincode
cd chaincode && npm run build

# Deploy to network
cd ../fabric && ./deploy-all-chaincodes.sh
```

### Writing Chaincode

Implement contracts in `chaincode/src/index.ts` using the Fabric Chaincode Node SDK:

```typescript
import { Contract, Context } from 'fabric-chaincode-node';

export class TokenContract extends Contract {
  async issueToken(ctx: Context, customerId: string, consentId: string): Promise<void> {
    // Token logic
  }

  async validateToken(ctx: Context, tokenId: string): Promise<string> {
    // Validation logic
  }
}
```

For SDK documentation, see [Fabric Chaincode Node Docs](https://hyperledger-fabric.readthedocs.io/en/latest/chaincode4ade.html#node-chaincode).
