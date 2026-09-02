#!/bin/bash

# ============================================================================
# CHANNEL DEPLOYMENT SCRIPT
# Creates mychannel and joins orderer and both peers
# ============================================================================

set -e

echo "============================================================================"
echo "📡 Creating Channels"
echo "============================================================================"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Setup environment
export PATH=${PWD}/../bin:${PATH}
export FABRIC_CFG_PATH=${PWD}/config
export CORE_PEER_TLS_ENABLED=true

# Verify required binaries
command -v configtxgen >/dev/null 2>&1 || error_exit "configtxgen not found in PATH"
command -v osnadmin >/dev/null 2>&1    || error_exit "osnadmin not found in PATH"
command -v peer >/dev/null 2>&1        || error_exit "peer not found in PATH"

mkdir -p channel-artifacts || error_exit "Failed to create channel-artifacts directory"

# Function to join orderer to channel
joinOrderer() {
    local CHANNEL=$1

    echo -e "${BLUE}Joining orderer to $CHANNEL...${NC}"

    local OUTPUT
    OUTPUT=$(osnadmin channel join \
        --channelID $CHANNEL \
        --config-block ./channel-artifacts/${CHANNEL}.block \
        -o localhost:7053 \
        --ca-file ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --client-cert ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt \
        --client-key ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key \
        2>&1)

    if echo "$OUTPUT" | grep -q "Status: 201"; then
        echo -e "${GREEN}  ✓ orderer joined successfully${NC}"
        return 0
    elif echo "$OUTPUT" | grep -q "already exists"; then
        echo -e "${YELLOW}  ⚠ orderer already in channel${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to join orderer${NC}"
        echo "$OUTPUT"
        return 1
    fi
}

# Function to set peer environment
setPeerEnv() {
    local ORG=$1
    local MSP=$2
    local PORT=$3

    export CORE_PEER_LOCALMSPID="${MSP}"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${ORG}.example.com/peers/peer0.${ORG}.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${ORG}.example.com/users/Admin@${ORG}.example.com/msp
    export CORE_PEER_ADDRESS=localhost:${PORT}
}

# Function to join peer to channel
joinPeer() {
    local ORG=$1
    local CHANNEL=$2

    local OUTPUT
    OUTPUT=$(peer channel join -b ./channel-artifacts/${CHANNEL}.block 2>&1)

    if echo "$OUTPUT" | grep -q "Successfully submitted proposal to join channel"; then
        echo -e "${GREEN}  ✓ $ORG joined $CHANNEL${NC}"
        return 0
    elif echo "$OUTPUT" | grep -q "already exists"; then
        echo -e "${YELLOW}  ⚠ $ORG already in $CHANNEL${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed to join $ORG to $CHANNEL${NC}"
        echo "$OUTPUT"
        return 1
    fi
}

# Generate genesis block for mychannel
echo -e "${YELLOW}Creating mychannel...${NC}"

if ! FABRIC_CFG_PATH=${PWD}/configtx configtxgen -profile TwoOrgsChannel \
    -outputBlock ./channel-artifacts/mychannel.block \
    -channelID mychannel > /dev/null 2>&1; then
    error_exit "Failed to generate genesis block for mychannel"
fi

# Join orderer to mychannel
joinOrderer "mychannel" || error_exit "Failed to join orderer to mychannel"

sleep 2

# Join buyer peer
echo -e "${BLUE}Joining peers to mychannel...${NC}"
setPeerEnv "buyer" "BuyerMSP" "7051"
joinPeer "buyer" "mychannel" || error_exit "Failed to join buyer to mychannel"

# Join seller peer
setPeerEnv "seller" "SellerMSP" "8051"
joinPeer "seller" "mychannel" || error_exit "Failed to join seller to mychannel"

echo ""
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}✅ mychannel created and both peers joined!${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo ""
echo "Waiting for Raft consensus to stabilize (10 seconds)..."
sleep 10
echo -e "${GREEN}✅ Ready for chaincode deployment${NC}"
