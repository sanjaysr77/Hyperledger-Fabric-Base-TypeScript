# AssetChain Network — Complete User Guide
### For someone who has never used blockchain before

---

## What is this project?

Think of this project as a **shared digital ledger** between two companies — a **Buyer** and a **Seller**. Instead of each company keeping their own spreadsheet (which can be faked or edited), they share a blockchain where every record is permanent, tamper-proof, and visible to both parties.

Here's the big picture of what's running on your machine:

```
┌─────────────────────────────────────────────────────┐
│                  YOUR MACHINE                       │
│                                                     │
│  ┌──────────┐   ┌──────────┐   ┌─────────────────┐  │
│  │  Buyer   │   │  Seller  │   │    Orderer      │  │
│  │  Peer    │   │  Peer    │   │  (like a post   │  │
│  │ (node)   │   │ (node)   │   │   office that   │  │
│  │          │   │          │   │   orders blocks)│  │
│  │ CouchDB  │   │ CouchDB  │   └─────────────────┘  │
│  │ (storage)│   │ (storage)│                        │
│  └──────────┘   └──────────┘                        │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │         Gateway App (Node.js API)            │   │
│  │         Runs on http://localhost:3000        │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

- **Peer** = A computer node that holds a copy of the blockchain
- **Orderer** = Orders and packages transactions into blocks
- **CouchDB** = The database where each peer stores its data (you can browse it visually)
- **Chaincode** = The smart contract (Go code) that defines the rules — like "only the owner can delete an asset"
- **Channel (mychannel)** = The private communication lane between Buyer and Seller
- **Gateway App** = The REST API you talk to from Postman

---

## Part 1 — Starting Everything

### Step 1: Start the blockchain network

Open a terminal in the `assetchain_network_v2` folder and run:

```bash
./network.sh up
./network.sh createchannel
./network.sh deploycc
```

You only need to do this once. After that, to start/stop:

```bash
./network.sh stop     # pause (keeps all data)
./network.sh start    # resume
```

To completely wipe and start fresh:
```bash
./network.sh cleanall
./network.sh all
```

### Step 2: Start the Gateway API server

Open a **new terminal** in the `gateway-app` folder:

```bash
cd assetchain_network_v2/gateway-app
npm install
npm start
```

You should see:
```
==================================================
Simple Fabric Network Gateway
Hyperledger Fabric 2.5.x
==================================================
Server running on port 3000
Health check: http://localhost:3000/health
```

Keep this terminal open. This is your API server.

---

## Part 2 — Verify Everything is Running

### Check 1: Docker containers

Run this in a terminal:
```bash
docker ps
```

You should see these 4 containers running:
| Container Name | What it is |
|---|---|
| `orderer.example.com` | The block orderer |
| `peer0.buyer.example.com` | Buyer's blockchain node |
| `peer0.seller.example.com` | Seller's blockchain node |
| `couchdb.buyer` | Buyer's database |
| `couchdb.seller` | Seller's database |

### Check 2: API health check

Open Postman (or your browser) and hit:
```
GET http://localhost:3000/health
```

Expected response:
```json
{
  "success": true,
  "message": "Fabric Network Gateway API is running",
  "version": "1.0.0",
  "fabric": "2.5.x"
}
```

### Check 3: CouchDB visual browser

CouchDB has a built-in web UI. Open your browser and go to:

- **Buyer's database:** http://localhost:7984/_utils
- **Seller's database:** http://localhost:8984/_utils

Login with:
- Username: `admin`
- Password: `adminpw`

Here you can see every asset stored on the blockchain as JSON documents. After you create assets via the API, they will appear here.

---

## Part 3 — Using the API in Postman

### Setup in Postman

1. Open Postman
2. Create a new Collection called "AssetChain"
3. Set a Collection Variable: `baseUrl` = `http://localhost:3000`
4. For authenticated requests, add this header: `Authorization: Bearer {{token}}`

---

### Authentication

#### Register a new admin user

Before you can do anything, you need a user in MongoDB. Use this endpoint to create one:

```
POST http://localhost:3000/api/auth/register
```

Body (JSON):
```json
{
  "name": "BuyerAdmin",
  "email": "admin@buyer.com",
  "phone": "9999999999",
  "password": "password123",
  "role": "admin",
  "organization": "buyer"
}
```


#### Login

```
POST http://localhost:3000/api/auth/login
```

Body (JSON):
```json
{
  "username": "admin@buyer.com",
  "password": "password123"
}
```

Expected response:
```json
{
  "success": true,
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "username": "BuyerAdmin",
    "role": "admin",
    "organization": "buyer",
    "orgType": "buyer"
  }
}
```

**Copy the `token` value** — you'll need it for all other requests.

#### Verify your token is valid

```
GET http://localhost:3000/api/auth/verify
Headers: Authorization: Bearer <your_token>
```

---

### Asset Operations (the blockchain part)

All asset operations write to / read from the **blockchain**. Every write creates a new block.

> Important: Assets are stored in **private collections** — Buyer's assets go into `buyerPrivateDetails` and Seller's assets go into `sellerPrivateDetails`. This means each org can only see their own assets.

#### Create an Asset

```
POST http://localhost:3000/api/asset
Headers: Authorization: Bearer <your_token>
```

Body (JSON):
```json
{
  "assetId": "ASSET001",
  "name": "Laptop",
  "description": "Dell XPS 15 laptop",
  "owner": "buyer",
  "status": "Active",
  "value": "75000"
}
```

Expected response:
```json
{
  "success": true,
  "message": "Asset created successfully"
}
```

What happens behind the scenes:
1. Your request hits the Gateway API
2. The API connects to `peer0.buyer.example.com` using the Admin identity
3. The peer runs the chaincode (smart contract)
4. The chaincode stores the asset in `buyerPrivateDetails` collection
5. The transaction is sent to the Orderer
6. The Orderer packages it into a block
7. The block is added to the blockchain on both peers
8. CouchDB is updated — you can now see it at http://localhost:7984/_utils

#### Get a Single Asset

```
GET http://localhost:3000/api/asset/ASSET001
Headers: Authorization: Bearer <your_token>
```

Expected response:
```json
{
  "success": true,
  "data": {
    "docType": "asset",
    "assetId": "ASSET001",
    "name": "Laptop",
    "description": "Dell XPS 15 laptop",
    "owner": "buyer",
    "status": "Active",
    "value": "75000"
  }
}
```

#### Get All Assets

```
GET http://localhost:3000/api/asset
Headers: Authorization: Bearer <your_token>
```

#### Update an Asset

```
PUT http://localhost:3000/api/asset/ASSET001
Headers: Authorization: Bearer <your_token>
```

Body (JSON):
```json
{
  "name": "Laptop",
  "description": "Dell XPS 15 laptop - Updated",
  "owner": "buyer",
  "status": "In Use",
  "value": "70000"
}
```

#### Get Asset History (blockchain audit trail)

This is one of the most powerful blockchain features — you can see every change ever made to an asset, who made it, and when.

```
GET http://localhost:3000/api/asset/ASSET001/history // Doesn't Work
Headers: Authorization: Bearer <your_token>
```

Expected response:
```json
{
  "success": true,
  "data": [
    {
      "TxId": "8b46b1f41e7a5eb0...",
      "Value": { "assetId": "ASSET001", "status": "In Use", "value": "70000" },
      "IsDelete": "false"
    },
    {
      "TxId": "56b65bba61b895fe...",
      "Value": { "assetId": "ASSET001", "status": "Active", "value": "75000" },
      "IsDelete": "false"
    }
  ]
}
```

Each entry is a separate block on the blockchain. You cannot delete or edit history — that's the whole point of blockchain.

#### Delete an Asset

```
DELETE http://localhost:3000/api/asset/ASSET001
Headers: Authorization: Bearer <your_token>
```

> Note: Even after deletion, the history endpoint will still show all previous versions. The blockchain never forgets.

---

### User Management Operations

#### Create a User

```
POST http://localhost:3000/api/user/users
Headers: Authorization: Bearer <your_token>
```

Body (JSON):
```json
{
  "name": "John Doe",
  "email": "john@buyer.com",
  "phone": "8888888888",
  "password": "pass123",
  "role": "user",
  "status": "Active"
}
```

#### Get All Users

```
GET http://localhost:3000/api/user/users
Headers: Authorization: Bearer <your_token>
```

#### Get a Specific User

```
GET http://localhost:3000/api/user/users/John Doe
Headers: Authorization: Bearer <your_token>
```

#### Delete a User

```
DELETE http://localhost:3000/api/user/users/John Doe
Headers: Authorization: Bearer <your_token>
```

---

## Part 4 — Viewing the Blockchain Visually

### CouchDB (see the actual stored data)

1. Go to http://localhost:7984/_utils (Buyer) or http://localhost:8984/_utils (Seller)
2. Login: `admin` / `adminpw`
3. Click on a database name (you'll see collections like `mychannel_`)
4. Click on any document to see the full JSON of an asset

This is the **current state** of the ledger — the latest version of every asset.

### View raw blockchain blocks (advanced)

To see the actual blocks being created, run this in a terminal:

```bash
export PATH=$PATH:$(pwd)/bin
export FABRIC_CFG_PATH=$(pwd)/config
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=BuyerMSP
export CORE_PEER_ADDRESS=localhost:7051
export CORE_PEER_TLS_ROOTCERT_FILE=$(pwd)/organizations/peerOrganizations/buyer.example.com/peers/peer0.buyer.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$(pwd)/organizations/peerOrganizations/buyer.example.com/users/Admin@buyer.example.com/msp

# Get info about the channel (shows how many blocks exist)
peer channel getinfo -c mychannel
```

You'll see something like:
```
Blockchain info: {"height":5,"currentBlockHash":"abc123...","previousBlockHash":"def456..."}
```

`height: 5` means there are 5 blocks. Every transaction adds a new block.

To fetch a specific block (e.g. block number 2):
```bash
peer channel fetch 2 block2.pb -c mychannel -o localhost:7050 \
  --tls --cafile $(pwd)/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

### View peer logs (see transactions in real time)

```bash
docker logs -f peer0.buyer.example.com
```

Every time you hit an API endpoint that writes to the blockchain, you'll see log lines appear here. Press `Ctrl+C` to stop watching.

---

## Part 5 — Complete Flow Example (end to end)

Here's a full walkthrough to test everything works:

**1. Start the network** (if not already running)
```bash
./network.sh up
./network.sh createchannel
./network.sh deploycc
```

**2. Start the API server**
```bash
cd gateway-app && npm start
```

**3. In Postman — Login**
```
POST http://localhost:3000/api/auth/login
Body: { "username": "admin@buyer.com", "password": "password123" }
```
Copy the token from the response.

**4. In Postman — Create an asset**
```
POST http://localhost:3000/api/asset
Authorization: Bearer <token>
Body: { "assetId": "TEST001", "name": "Test Item", "description": "My first blockchain asset", "owner": "buyer", "status": "Active", "value": "1000" }
```

**5. Check CouchDB** — Go to http://localhost:7984/_utils and find TEST001

**6. In Postman — Update the asset**
```
PUT http://localhost:3000/api/asset/TEST001
Authorization: Bearer <token>
Body: { "name": "Test Item", "description": "Updated description", "owner": "buyer", "status": "Sold", "value": "900" }
```

**7. In Postman — Check the history**
```
GET http://localhost:3000/api/asset/TEST001/history
Authorization: Bearer <token>
```
You'll see 2 entries — the original creation and the update. This is the immutable audit trail.

**8. Check block count**
```bash
peer channel getinfo -c mychannel
```
The height will have increased — each transaction added a block.

---

## Part 6 — Troubleshooting

| Problem | What to check |
|---|---|
| `docker ps` shows no containers | Run `./network.sh up` again |
| API returns 500 error | Check the `npm start` terminal for error messages |
| CouchDB shows no data | Make sure you created assets via the API first |
| Login returns "Invalid credentials" | The user doesn't exist in MongoDB yet — register first |
| `peer channel getinfo` fails | Make sure you exported all the environment variables |
| Gateway can't connect to peer | Make sure Docker containers are running (`docker ps`) |

---

## Quick Reference — All API Endpoints

| Method | URL | Auth Required | What it does |
|---|---|---|---|
| GET | `/health` | No | Check if server is running |
| POST | `/api/auth/register` | No | Create a new user |
| POST | `/api/auth/login` | No | Login and get token |
| GET | `/api/auth/verify` | Yes | Check if token is valid |
| POST | `/api/asset` | Yes | Create asset on blockchain |
| GET | `/api/asset` | Yes | Get all assets |
| GET | `/api/asset/:id` | Yes | Get one asset |
| PUT | `/api/asset/:id` | Yes | Update asset on blockchain |
| DELETE | `/api/asset/:id` | Yes | Delete asset from blockchain |
| GET | `/api/asset/:id/history` | Yes | Full audit trail for asset |
| POST | `/api/user/users` | Yes (Admin) | Create a user |
| GET | `/api/user/users` | Yes (Admin) | Get all users |
| GET | `/api/user/users/:name` | Yes | Get one user |
| DELETE | `/api/user/users/:name` | Yes (Admin) | Delete a user |

---

## Key Concepts Summary

| Term | Simple explanation |
|---|---|
| **Blockchain** | A chain of blocks where each block contains transactions. Once written, it cannot be changed. |
| **Block** | A package of one or more transactions. Like a page in a ledger book. |
| **Transaction** | One action — creating, updating, or deleting an asset. |
| **Chaincode** | The smart contract — Go code that defines the rules of what can be stored and who can access it. |
| **Channel** | A private lane of communication. Only Buyer and Seller are on `mychannel`. |
| **Peer** | A node that holds a full copy of the blockchain. Both Buyer and Seller have one. |
| **Orderer** | Packages transactions into blocks and distributes them to all peers. |
| **CouchDB** | The database that stores the current state of all assets (the latest version). |
| **Private Collection** | Data that only one org can see. Buyer's assets are hidden from Seller and vice versa. |
| **MSP** | Membership Service Provider — manages identities and certificates for each org. |
| **JWT Token** | A security token you get after login. Include it in every API request. |
