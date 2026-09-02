## Chaincode Setup

### Option 1: TypeScript Chaincode (In This Repo)

The `chaincode/` folder is set up for TypeScript smart contracts. Write your contracts here and deploy them directly:

```bash
./deploy-all-chaincodes.sh
```

### Option 2: Separate TS Project

If you're using this repo purely for network infrastructure, delete the `chaincode/` folder and manage smart contracts in a dedicated TypeScript project. Clone just the HLF setup when you need it.

---