#!/bin/bash

# ============================================================================
# CHANNEL DEPLOYMENT SCRIPT
# Creates kycTokenChannel and joins orderer and all three peers
# ============================================================================

set -e

echo "============================================================================"
echo "📡 Creating kycTokenChannel"
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

# ============================================================================
# Setup environment
# ============================================================================

# Determine script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

export FABRIC_CFG_PATH=${PROJECT_ROOT}/configtx
export CORE_PEER_TLS_ENABLED=true

# Add fabric-samples/bin to PATH if it exists, otherwise assume binaries are in system PATH
if [ -d "${PROJECT_ROOT}/../bin" ]; then
    export PATH=${PROJECT_ROOT}/../bin:${PATH}
fi

# Change to project root for relative path references
cd "$PROJECT_ROOT"

# ============================================================================
# Verify required binaries
# ============================================================================

command -v configtxgen >/dev/null 2>&1 || error_exit "configtxgen not found in PATH"
command -v osnadmin >/dev/null 2>&1    || error_exit "osnadmin not found in PATH"
command -v peer >/dev/null 2>&1        || error_exit "peer not found in PATH"

mkdir -p channel-artifacts || error_exit "Failed to create channel-artifacts directory"

# ============================================================================
# Function to join orderer to channel
# ============================================================================

joinOrderer() {

    local CHANNEL=$1

    echo -e "${BLUE}Joining orderer to $CHANNEL...${NC}"

    local OUTPUT

    OUTPUT=$(osnadmin channel join \
        --channelID $CHANNEL \
        --config-block ${PROJECT_ROOT}/channel-artifacts/${CHANNEL}.block \
        -o localhost:7053 \
        --ca-file ${PROJECT_ROOT}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --client-cert ${PROJECT_ROOT}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt \
        --client-key ${PROJECT_ROOT}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key \
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

# ============================================================================
# Function to set peer environment
# ============================================================================

setPeerEnv() {

    local ORG=$1
    local MSP=$2
    local PORT=$3

    export CORE_PEER_LOCALMSPID="${MSP}"

    export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_ROOT}/organizations/peerOrganizations/${ORG}.example.com/peers/peer0.${ORG}.example.com/tls/ca.crt

    export CORE_PEER_MSPCONFIGPATH=${PROJECT_ROOT}/organizations/peerOrganizations/${ORG}.example.com/users/Admin@${ORG}.example.com/msp

    export CORE_PEER_ADDRESS=localhost:${PORT}
    
    export FABRIC_CFG_PATH=${PROJECT_ROOT}/config
}

# ============================================================================
# Function to join peer to channel
# ============================================================================

joinPeer() {

    local ORG=$1
    local CHANNEL=$2

    local OUTPUT

    OUTPUT=$(peer channel join \
        -b ${PROJECT_ROOT}/channel-artifacts/${CHANNEL}.block \
        2>&1)

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

# ============================================================================
# Generate channel block
# ============================================================================

CHANNEL="kyctokenchannel"

echo -e "${YELLOW}Creating ${CHANNEL}...${NC}"

if ! FABRIC_CFG_PATH=${PROJECT_ROOT}/configtx configtxgen \
    -profile kyctokenchannel \
    -outputBlock ./channel-artifacts/${CHANNEL}.block \
    -channelID ${CHANNEL} 2>&1; then

    error_exit "Failed to generate genesis block for ${CHANNEL}"
fi

echo -e "${GREEN}  ✓ Channel block generated${NC}"

# ============================================================================
# Join orderer
# ============================================================================

joinOrderer "${CHANNEL}" || \
    error_exit "Failed to join orderer to ${CHANNEL}"

sleep 2

# ============================================================================
# Join Org1 peer
# ============================================================================

echo -e "${BLUE}Joining peers to ${CHANNEL}...${NC}"

setPeerEnv "org1" "Org1MSP" "7051"

joinPeer "Org1" "${CHANNEL}" || \
    error_exit "Failed to join Org1 to ${CHANNEL}"

# ============================================================================
# Join Org2 peer
# ============================================================================

setPeerEnv "org2" "Org2MSP" "8051"

joinPeer "Org2" "${CHANNEL}" || \
    error_exit "Failed to join Org2 to ${CHANNEL}"

# ============================================================================
# Join Org3 peer
# ============================================================================

setPeerEnv "org3" "Org3MSP" "9051"

joinPeer "Org3" "${CHANNEL}" || \
    error_exit "Failed to join Org3 to ${CHANNEL}"

# ============================================================================
# Complete
# ============================================================================

echo ""

echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}✅ ${CHANNEL} created and all three peers joined!${NC}"
echo -e "${GREEN}============================================================================${NC}"

echo ""

echo "Waiting for Raft consensus to stabilize (10 seconds)..."

sleep 10

echo -e "${GREEN}✅ Ready for chaincode deployment${NC}"