#!/bin/bash

# ============================================================================
# CHAINCODE DEPLOYMENT SCRIPT
# Packages, installs, approves and commits the KYC token chaincode
# ============================================================================

set -e

echo "============================================================================"
echo "🚀 Deploying KYC Token Chaincode"
echo "============================================================================"

# ============================================================================
# Colors
# ============================================================================

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

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

export CORE_PEER_TLS_ENABLED=true

# Add Fabric binaries to PATH if they exist
if [ -d "${PROJECT_ROOT}/../bin" ]; then
    export PATH="${PROJECT_ROOT}/../bin:${PATH}"
fi

cd "$PROJECT_ROOT"

export FABRIC_CFG_PATH="${PROJECT_ROOT}/config"

# ============================================================================
# Chaincode configuration
# ============================================================================

ORDERER_CA="${PROJECT_ROOT}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

CHANNEL="kyctokenchannel"

CC_NAME="kyc-token-cc"

# Previous committed definition:
# Version: 1.2
# Sequence: 3
#
# This deployment contains the new GetConsent transaction.
CC_VERSION="1.3"
CC_SEQUENCE=4

CC_LABEL="${CC_NAME}_${CC_VERSION}"

# RecordConsent is a Bank / Org1 operation according to the project design.
CC_ENDORSEMENT_POLICY="OR('Org1MSP.member')"

# ============================================================================
# Function: Set peer environment
# ============================================================================

setPeerEnv() {

    local ORG=$1
    local MSP=$2
    local PORT=$3

    export CORE_PEER_LOCALMSPID="${MSP}"

    export CORE_PEER_TLS_ROOTCERT_FILE="${PROJECT_ROOT}/organizations/peerOrganizations/${ORG}.example.com/peers/peer0.${ORG}.example.com/tls/ca.crt"

    export CORE_PEER_MSPCONFIGPATH="${PROJECT_ROOT}/organizations/peerOrganizations/${ORG}.example.com/users/Admin@${ORG}.example.com/msp"

    export CORE_PEER_ADDRESS="localhost:${PORT}"

    export FABRIC_CFG_PATH="${PROJECT_ROOT}/config"
}

# ============================================================================
# Step 0: Build TypeScript chaincode
# ============================================================================

echo -e "${YELLOW}Building TypeScript chaincode...${NC}"

cd "${PROJECT_ROOT}/chaincode"

npm run build || error_exit "Failed to build chaincode"

cd "${PROJECT_ROOT}" > /dev/null

echo -e "${GREEN}  ✓ Chaincode built${NC}"

# ============================================================================
# Step 1: Package chaincode
# ============================================================================

echo -e "${YELLOW}Packaging KYC token chaincode...${NC}"

rm -f "${CC_LABEL}.tar.gz"

peer lifecycle chaincode package "${CC_LABEL}.tar.gz" \
    --path "${PROJECT_ROOT}/chaincode" \
    --lang node \
    --label "${CC_LABEL}" \
    || error_exit "Failed to package chaincode"

echo -e "${GREEN}  ✓ Chaincode packaged${NC}"

# ============================================================================
# Step 2: Install on Org1
# ============================================================================

echo -e "${YELLOW}Installing on Org1 peer...${NC}"

setPeerEnv "org1" "Org1MSP" "7051"

peer lifecycle chaincode install "${CC_LABEL}.tar.gz" \
    || error_exit "Failed to install chaincode on Org1"

echo -e "${GREEN}  ✓ Installed on Org1${NC}"

# ============================================================================
# Step 3: Install on Org2
# ============================================================================

echo -e "${YELLOW}Installing on Org2 peer...${NC}"

setPeerEnv "org2" "Org2MSP" "8051"

peer lifecycle chaincode install "${CC_LABEL}.tar.gz" \
    || error_exit "Failed to install chaincode on Org2"

echo -e "${GREEN}  ✓ Installed on Org2${NC}"

# ============================================================================
# Step 4: Install on Org3
# ============================================================================

echo -e "${YELLOW}Installing on Org3 peer...${NC}"

setPeerEnv "org3" "Org3MSP" "9051"

peer lifecycle chaincode install "${CC_LABEL}.tar.gz" \
    || error_exit "Failed to install chaincode on Org3"

echo -e "${GREEN}  ✓ Installed on Org3${NC}"

# ============================================================================
# Step 5: Get package ID
# ============================================================================

echo -e "${YELLOW}Getting package ID...${NC}"

setPeerEnv "org1" "Org1MSP" "7051"

PACKAGE_ID=$(
    peer lifecycle chaincode queryinstalled 2>&1 |
    grep "Label: ${CC_LABEL}" |
    tail -1 |
    awk -F 'Package ID: ' '{print $2}' |
    awk -F ', Label' '{print $1}'
)

if [ -z "$PACKAGE_ID" ]; then
    error_exit "Could not find package ID for ${CC_LABEL}"
fi

echo -e "${BLUE}  Package ID: ${PACKAGE_ID}${NC}"

# ============================================================================
# Step 6: Approve for Org1
# ============================================================================

echo -e "${YELLOW}Approving chaincode for Org1...${NC}"

setPeerEnv "org1" "Org1MSP" "7051"

peer lifecycle chaincode approveformyorg \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --channelID "${CHANNEL}" \
    --name "${CC_NAME}" \
    --version "${CC_VERSION}" \
    --package-id "${PACKAGE_ID}" \
    --sequence "${CC_SEQUENCE}" \
    --signature-policy "${CC_ENDORSEMENT_POLICY}" \
    --tls \
    --cafile "${ORDERER_CA}" \
    || error_exit "Failed to approve for Org1"

echo -e "${GREEN}  ✓ Approved for Org1${NC}"

# ============================================================================
# Step 7: Approve for Org2
# ============================================================================

echo -e "${YELLOW}Approving chaincode for Org2...${NC}"

setPeerEnv "org2" "Org2MSP" "8051"

peer lifecycle chaincode approveformyorg \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --channelID "${CHANNEL}" \
    --name "${CC_NAME}" \
    --version "${CC_VERSION}" \
    --package-id "${PACKAGE_ID}" \
    --sequence "${CC_SEQUENCE}" \
    --signature-policy "${CC_ENDORSEMENT_POLICY}" \
    --tls \
    --cafile "${ORDERER_CA}" \
    || error_exit "Failed to approve for Org2"

echo -e "${GREEN}  ✓ Approved for Org2${NC}"

# ============================================================================
# Step 8: Approve for Org3
# ============================================================================

echo -e "${YELLOW}Approving chaincode for Org3...${NC}"

setPeerEnv "org3" "Org3MSP" "9051"

peer lifecycle chaincode approveformyorg \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --channelID "${CHANNEL}" \
    --name "${CC_NAME}" \
    --version "${CC_VERSION}" \
    --package-id "${PACKAGE_ID}" \
    --sequence "${CC_SEQUENCE}" \
    --signature-policy "${CC_ENDORSEMENT_POLICY}" \
    --tls \
    --cafile "${ORDERER_CA}" \
    || error_exit "Failed to approve for Org3"

echo -e "${GREEN}  ✓ Approved for Org3${NC}"

# ============================================================================
# Step 9: Check commit readiness
# ============================================================================

echo -e "${YELLOW}Checking commit readiness...${NC}"

setPeerEnv "org1" "Org1MSP" "7051"

peer lifecycle chaincode checkcommitreadiness \
    --channelID "${CHANNEL}" \
    --name "${CC_NAME}" \
    --version "${CC_VERSION}" \
    --sequence "${CC_SEQUENCE}" \
    --signature-policy "${CC_ENDORSEMENT_POLICY}" \
    --tls \
    --cafile "${ORDERER_CA}" \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --output json

# ============================================================================
# Step 10: Commit chaincode
# ============================================================================

echo -e "${YELLOW}Committing KYC token chaincode...${NC}"

setPeerEnv "org1" "Org1MSP" "7051"

peer lifecycle chaincode commit \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --channelID "${CHANNEL}" \
    --name "${CC_NAME}" \
    --version "${CC_VERSION}" \
    --sequence "${CC_SEQUENCE}" \
    --signature-policy "${CC_ENDORSEMENT_POLICY}" \
    --tls \
    --cafile "${ORDERER_CA}" \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles "${PROJECT_ROOT}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    --peerAddresses localhost:8051 \
    --tlsRootCertFiles "${PROJECT_ROOT}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles "${PROJECT_ROOT}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt" \
    || error_exit "Failed to commit chaincode"

echo -e "${GREEN}  ✓ Chaincode committed${NC}"

# ============================================================================
# Done
# ============================================================================

echo ""

echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}✅ KYC token chaincode deployed successfully on ${CHANNEL}!${NC}"
echo -e "${GREEN}============================================================================${NC}"