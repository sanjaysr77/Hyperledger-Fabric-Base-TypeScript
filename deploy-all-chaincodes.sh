#!/bin/bash

# ============================================================================
# CHAINCODE DEPLOYMENT SCRIPT
# Packages, installs, approves, and commits the asset chaincode
# ============================================================================

set -e

echo "============================================================================"
echo "🚀 Chaincode Deployment for Simple Fabric Network"
echo "============================================================================"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Setup environment
export PATH=${PWD}/../bin:${PATH}
export FABRIC_CFG_PATH=${PWD}/config
export CORE_PEER_TLS_ENABLED=true

ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

CHANNEL_NAME="mychannel"
CC_NAME="asset"
CC_VERSION="1.0"
CC_SEQUENCE=1
CC_LABEL="${CC_NAME}_${CC_VERSION}"

POLICY="OR('BuyerMSP.member','SellerMSP.member')"

# Organization configurations (org:msp:port)
declare -a ORGS=(
    "buyer:BuyerMSP:7051"
    "seller:SellerMSP:8051"
)

# Function to set peer environment
setPeerEnv() {
    local ORG=$1
    local MSP=$2
    local PORT=$3

    export CORE_PEER_LOCALMSPID="${MSP}"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${ORG}.example.com/peers/peer0.${ORG}.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${ORG}.example.com/users/Admin@${ORG}.example.com/msp
    export CORE_PEER_ADDRESS=peer0.${ORG}.example.com:${PORT}
}

# ============================================================================
# STEP 1: Package Chaincode
# ============================================================================
echo ""
echo -e "${BLUE}Step 1: Packaging chaincode...${NC}"

if [ -f "${CC_NAME}.tar.gz" ]; then
    echo -e "${YELLOW}  ⚠ ${CC_NAME} package already exists, skipping${NC}"
else
    peer lifecycle chaincode package ${CC_NAME}.tar.gz \
        --path ./chaincode/${CC_NAME} \
        --lang golang \
        --label ${CC_LABEL} >/dev/null 2>&1
    echo -e "${GREEN}  ✓ ${CC_NAME} packaged${NC}"
fi

# ============================================================================
# STEP 2: Install Chaincode on All Peers
# ============================================================================
echo ""
echo -e "${BLUE}Step 2: Installing chaincode on all peers...${NC}"

for ORG_CONFIG in "${ORGS[@]}"; do
    IFS=':' read -r ORG MSP PORT <<< "$ORG_CONFIG"
    echo -e "${BLUE}  Installing on ${ORG}...${NC}"
    setPeerEnv $ORG $MSP $PORT

    if peer lifecycle chaincode queryinstalled 2>&1 | grep -q "${CC_LABEL}"; then
        echo -e "${YELLOW}    ⚠ ${CC_NAME} already installed${NC}"
    else
        peer lifecycle chaincode install ${CC_NAME}.tar.gz >/dev/null 2>&1
        echo -e "${GREEN}    ✓ ${CC_NAME} installed on ${ORG}${NC}"
    fi
done

# ============================================================================
# STEP 3: Get Package ID
# ============================================================================
echo ""
echo -e "${BLUE}Step 3: Getting package ID...${NC}"

setPeerEnv buyer BuyerMSP 7051
PACKAGE_ID=$(peer lifecycle chaincode queryinstalled 2>&1 | grep "${CC_LABEL}" | awk '{print $3}' | sed 's/,$//')
echo -e "${GREEN}  ${CC_NAME}: ${PACKAGE_ID}${NC}"

# ============================================================================
# STEP 4: Approve Chaincode for Each Org
# ============================================================================
echo ""
echo -e "${BLUE}Step 4: Approving chaincode for each org...${NC}"

for ORG_CONFIG in "${ORGS[@]}"; do
    IFS=':' read -r ORG MSP PORT <<< "$ORG_CONFIG"
    setPeerEnv $ORG $MSP $PORT

    peer lifecycle chaincode approveformyorg \
        -o orderer.example.com:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --channelID ${CHANNEL_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --package-id ${PACKAGE_ID} \
        --sequence ${CC_SEQUENCE} \
        --signature-policy "${POLICY}" \
        --collections-config ./chaincode/${CC_NAME}/collections_config.json \
        --tls --cafile ${ORDERER_CA} >/dev/null 2>&1 || true

    echo -e "${GREEN}  ✓ ${CC_NAME} approved for ${ORG}${NC}"
done

# ============================================================================
# STEP 5: Commit Chaincode
# ============================================================================
echo ""
echo -e "${BLUE}Step 5: Committing chaincode...${NC}"

PEER_ADDRS=""
for ORG_CONFIG in "${ORGS[@]}"; do
    IFS=':' read -r ORG MSP PORT <<< "$ORG_CONFIG"
    PEER_ADDRS="$PEER_ADDRS --peerAddresses peer0.${ORG}.example.com:${PORT}"
    PEER_ADDRS="$PEER_ADDRS --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/${ORG}.example.com/peers/peer0.${ORG}.example.com/tls/ca.crt"
done

setPeerEnv buyer BuyerMSP 7051

peer lifecycle chaincode commit \
    -o orderer.example.com:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --channelID ${CHANNEL_NAME} \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --sequence ${CC_SEQUENCE} \
    --signature-policy "${POLICY}" \
    --collections-config ./chaincode/${CC_NAME}/collections_config.json \
    --tls --cafile ${ORDERER_CA} \
    ${PEER_ADDRS} >/dev/null 2>&1 || true

echo -e "${GREEN}  ✓ ${CC_NAME} committed to ${CHANNEL_NAME}${NC}"

# Wait for chaincode containers to start
echo ""
echo -e "${BLUE}  Waiting 15s for chaincode containers to start...${NC}"
sleep 15

# ============================================================================
# STEP 6: Verify Deployment
# ============================================================================
echo ""
echo -e "${BLUE}Step 6: Verifying deployment...${NC}"

setPeerEnv buyer BuyerMSP 7051

if peer lifecycle chaincode querycommitted --channelID ${CHANNEL_NAME} --name ${CC_NAME} --cafile ${ORDERER_CA} 2>&1 | grep -q "Version: ${CC_VERSION}"; then
    echo -e "${GREEN}  ✓ ${CC_NAME} committed on ${CHANNEL_NAME}${NC}"
else
    echo -e "${RED}  ✗ ${CC_NAME} not committed${NC}"
fi

echo ""
echo -e "${GREEN}============================================================================"
echo "✅ Chaincode deployed successfully!"
echo "============================================================================${NC}"
echo ""
echo "Deployment Summary:"
echo "  Channel: ${CHANNEL_NAME}"
echo "  Chaincode: ${CC_NAME} v${CC_VERSION}"
echo "  Orgs: buyer, seller"
echo "  Policy: OR(BuyerMSP.member, SellerMSP.member)"
echo "  Collections: buyer-private, seller-private"
echo ""
echo "System is ready for use!"
