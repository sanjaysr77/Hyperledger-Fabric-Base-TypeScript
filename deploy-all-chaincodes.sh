#!/bin/bash

# ============================================================================
# eKYC CHAINCODE DEPLOYMENT SCRIPT
# Packages, installs, approves, commits, and verifies kyc-token-cc
# ============================================================================

set -e

echo "============================================================================"
echo "🚀 eKYC Chaincode Deployment"
echo "============================================================================"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================================
# Setup
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${PROJECT_ROOT}"

# Unset any inherited FABRIC_CFG_PATH from network.sh and set correctly
unset FABRIC_CFG_PATH
export PATH="${PROJECT_ROOT}/../bin:${PATH}"
export FABRIC_CFG_PATH="${PROJECT_ROOT}/config"
export CORE_PEER_TLS_ENABLED=true

ORDERER_CA="${PROJECT_ROOT}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

CHANNEL_NAME="kyctokenchannel"

CC_NAME="kyc-token-cc"
CC_VERSION="1.0"
CC_SEQUENCE=1
CC_LABEL="${CC_NAME}_${CC_VERSION}"

# Current eKYC organizations
declare -a ORGS=(
    "org1:Org1MSP:7051"
    "org2:Org2MSP:8051"
    "org3:Org3MSP:9051"
)

# ============================================================================
# Set peer environment
# ============================================================================

setPeerEnv() {

    local ORG=$1
    local MSP=$2
    local PORT=$3

    export CORE_PEER_LOCALMSPID="${MSP}"

    export CORE_PEER_TLS_ROOTCERT_FILE="${PROJECT_ROOT}/organizations/peerOrganizations/${ORG}.example.com/peers/peer0.${ORG}.example.com/tls/ca.crt"

    export CORE_PEER_MSPCONFIGPATH="${PROJECT_ROOT}/organizations/peerOrganizations/${ORG}.example.com/users/Admin@${ORG}.example.com/msp"

    export CORE_PEER_ADDRESS="peer0.${ORG}.example.com:${PORT}"
}

# ============================================================================
# STEP 0: Build TypeScript Chaincode
# ============================================================================

echo ""
echo -e "${BLUE}Step 0: Building TypeScript chaincode...${NC}"

cd "${PROJECT_ROOT}/chaincode"

npm run build

echo -e "${GREEN}✓ Chaincode built${NC}"

cd "${PROJECT_ROOT}"

# ============================================================================
# STEP 1: Package Chaincode
# ============================================================================

echo ""
echo -e "${BLUE}Step 1: Packaging chaincode...${NC}"

if [ -f "${CC_NAME}.tar.gz" ]; then

    echo -e "${YELLOW}⚠ ${CC_NAME}.tar.gz already exists${NC}"

else

    peer lifecycle chaincode package "${CC_NAME}.tar.gz" \
        --path "${PROJECT_ROOT}/chaincode" \
        --lang node \
        --label "${CC_LABEL}"

    echo -e "${GREEN}✓ ${CC_NAME} packaged${NC}"

fi

# ============================================================================
# STEP 2: Install Chaincode on All Peers
# ============================================================================

echo ""
echo -e "${BLUE}Step 2: Installing chaincode on all peers...${NC}"

for ORG_CONFIG in "${ORGS[@]}"; do

    IFS=':' read -r ORG MSP PORT <<< "${ORG_CONFIG}"

    echo -e "${BLUE}Installing on ${ORG}...${NC}"

    setPeerEnv "${ORG}" "${MSP}" "${PORT}"

    if peer lifecycle chaincode queryinstalled 2>&1 | grep -q "${CC_LABEL}"; then

        echo -e "${YELLOW}⚠ ${CC_NAME} already installed on ${ORG}${NC}"

    else

        peer lifecycle chaincode install "${CC_NAME}.tar.gz"

        echo -e "${GREEN}✓ ${CC_NAME} installed on ${ORG}${NC}"

    fi

done

# ============================================================================
# STEP 3: Get Package ID
# ============================================================================

echo ""
echo -e "${BLUE}Step 3: Getting package ID...${NC}"

setPeerEnv org1 Org1MSP 7051

PACKAGE_ID=$(
    peer lifecycle chaincode queryinstalled |
    grep "${CC_LABEL}" |
    awk '{print $3}' |
    sed 's/,$//'
)

if [ -z "${PACKAGE_ID}" ]; then

    echo -e "${RED}✗ Package ID not found${NC}"
    exit 1

fi

echo -e "${GREEN}✓ Package ID: ${PACKAGE_ID}${NC}"

# ============================================================================
# STEP 4: Approve Chaincode Definition
# ============================================================================

echo ""
echo -e "${BLUE}Step 4: Approving chaincode definition...${NC}"

for ORG_CONFIG in "${ORGS[@]}"; do

    IFS=':' read -r ORG MSP PORT <<< "${ORG_CONFIG}"

    echo -e "${BLUE}Approving for ${ORG}...${NC}"

    setPeerEnv "${ORG}" "${MSP}" "${PORT}"

    peer lifecycle chaincode approveformyorg \
        -o orderer.example.com:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --channelID "${CHANNEL_NAME}" \
        --name "${CC_NAME}" \
        --version "${CC_VERSION}" \
        --package-id "${PACKAGE_ID}" \
        --sequence "${CC_SEQUENCE}" \
        --tls \
        --cafile "${ORDERER_CA}"

    echo -e "${GREEN}✓ ${CC_NAME} approved for ${ORG}${NC}"

done

# ============================================================================
# STEP 5: Check Commit Readiness
# ============================================================================

echo ""
echo -e "${BLUE}Step 5: Checking commit readiness...${NC}"

setPeerEnv org1 Org1MSP 7051

peer lifecycle chaincode checkcommitreadiness \
    --channelID "${CHANNEL_NAME}" \
    --name "${CC_NAME}" \
    --version "${CC_VERSION}" \
    --sequence "${CC_SEQUENCE}" \
    --tls \
    --cafile "${ORDERER_CA}"

# ============================================================================
# STEP 6: Commit Chaincode
# ============================================================================

echo ""
echo -e "${BLUE}Step 6: Committing chaincode...${NC}"

PEER_ADDRS=""
PEER_TLS=""

for ORG_CONFIG in "${ORGS[@]}"; do

    IFS=':' read -r ORG MSP PORT <<< "${ORG_CONFIG}"

    PEER_ADDRS="${PEER_ADDRS} --peerAddresses peer0.${ORG}.example.com:${PORT}"

    PEER_TLS="${PEER_TLS} --tlsRootCertFiles ${PROJECT_ROOT}/organizations/peerOrganizations/${ORG}.example.com/peers/peer0.${ORG}.example.com/tls/ca.crt"

done

setPeerEnv org1 Org1MSP 7051

peer lifecycle chaincode commit \
    -o orderer.example.com:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --channelID "${CHANNEL_NAME}" \
    --name "${CC_NAME}" \
    --version "${CC_VERSION}" \
    --sequence "${CC_SEQUENCE}" \
    --tls \
    --cafile "${ORDERER_CA}" \
    ${PEER_ADDRS} \
    ${PEER_TLS}

echo -e "${GREEN}✓ ${CC_NAME} committed to ${CHANNEL_NAME}${NC}"

# ============================================================================
# STEP 7: Verify Deployment
# ============================================================================

echo ""
echo -e "${BLUE}Step 7: Verifying deployment...${NC}"

setPeerEnv org1 Org1MSP 7051

peer lifecycle chaincode querycommitted \
    --channelID "${CHANNEL_NAME}" \
    --name "${CC_NAME}" \
    --cafile "${ORDERER_CA}"

echo ""
echo -e "${GREEN}============================================================================"
echo "✅ eKYC Chaincode deployment complete"
echo "============================================================================${NC}"

echo ""
echo "Deployment Summary:"
echo "  Channel:   ${CHANNEL_NAME}"
echo "  Chaincode: ${CC_NAME} v${CC_VERSION}"
echo "  Orgs:      Org1, Org2, Org3"
echo "  Package:   ${PACKAGE_ID}"
echo ""