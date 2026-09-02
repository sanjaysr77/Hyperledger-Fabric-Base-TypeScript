#!/bin/bash

# ============================================================================
# CHAINCODE DEPLOYMENT SCRIPT
# Packages, installs, approves and commits the asset chaincode
# ============================================================================

set -e

echo "============================================================================"
echo "🚀 Deploying Asset Chaincode"
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

ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
CHANNEL="mychannel"
CC_NAME="asset"
CC_SRC_PATH="./chaincode/asset"
CC_VERSION="1.0"
CC_SEQUENCE=1
CC_LABEL="${CC_NAME}_${CC_VERSION}"
CC_POLICY="OR('BuyerMSP.peer','SellerMSP.peer')"

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

# Step 1: Package chaincode
echo -e "${YELLOW}Packaging chaincode...${NC}"
peer lifecycle chaincode package ${CC_LABEL}.tar.gz \
    --path ${CC_SRC_PATH} \
    --lang golang \
    --label ${CC_LABEL} || error_exit "Failed to package chaincode"
echo -e "${GREEN}  ✓ Chaincode packaged${NC}"

# Step 2: Install on buyer peer
echo -e "${YELLOW}Installing on buyer peer...${NC}"
setPeerEnv "buyer" "BuyerMSP" "7051"
peer lifecycle chaincode install ${CC_LABEL}.tar.gz 2>&1 | grep -v "already successfully installed" || true
echo -e "${GREEN}  ✓ Installed on buyer${NC}"

# Step 3: Install on seller peer
echo -e "${YELLOW}Installing on seller peer...${NC}"
setPeerEnv "seller" "SellerMSP" "8051"
peer lifecycle chaincode install ${CC_LABEL}.tar.gz 2>&1 | grep -v "already successfully installed" || true
echo -e "${GREEN}  ✓ Installed on seller${NC}"

# Step 4: Get package ID
setPeerEnv "buyer" "BuyerMSP" "7051"
PACKAGE_ID=$(peer lifecycle chaincode queryinstalled 2>&1 | grep "${CC_LABEL}" | awk -F 'Package ID: ' '{print $2}' | awk -F ', Label' '{print $1}')
if [ -z "$PACKAGE_ID" ]; then
    error_exit "Could not find package ID for ${CC_LABEL}"
fi
echo -e "${BLUE}  Package ID: ${PACKAGE_ID}${NC}"

# Step 5: Approve for buyer
echo -e "${YELLOW}Approving for buyer...${NC}"
setPeerEnv "buyer" "BuyerMSP" "7051"
peer lifecycle chaincode approveformyorg \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --channelID $CHANNEL \
    --name $CC_NAME \
    --version $CC_VERSION \
    --package-id $PACKAGE_ID \
    --sequence $CC_SEQUENCE \
    --signature-policy "$CC_POLICY" \
    --collections-config ./chaincode/asset/collections_config.json \
    --tls \
    --cafile $ORDERER_CA || error_exit "Failed to approve for buyer"
echo -e "${GREEN}  ✓ Approved for buyer${NC}"

# Step 6: Approve for seller
echo -e "${YELLOW}Approving for seller...${NC}"
setPeerEnv "seller" "SellerMSP" "8051"
peer lifecycle chaincode approveformyorg \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --channelID $CHANNEL \
    --name $CC_NAME \
    --version $CC_VERSION \
    --package-id $PACKAGE_ID \
    --sequence $CC_SEQUENCE \
    --signature-policy "$CC_POLICY" \
    --collections-config ./chaincode/asset/collections_config.json \
    --tls \
    --cafile $ORDERER_CA || error_exit "Failed to approve for seller"
echo -e "${GREEN}  ✓ Approved for seller${NC}"

# Step 7: Check commit readiness
echo -e "${YELLOW}Checking commit readiness...${NC}"
peer lifecycle chaincode checkcommitreadiness \
    --channelID $CHANNEL \
    --name $CC_NAME \
    --version $CC_VERSION \
    --sequence $CC_SEQUENCE \
    --signature-policy "$CC_POLICY" \
    --collections-config ./chaincode/asset/collections_config.json \
    --tls \
    --cafile $ORDERER_CA \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --output json

# Step 8: Commit chaincode
echo -e "${YELLOW}Committing chaincode...${NC}"
setPeerEnv "buyer" "BuyerMSP" "7051"
peer lifecycle chaincode commit \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --channelID $CHANNEL \
    --name $CC_NAME \
    --version $CC_VERSION \
    --sequence $CC_SEQUENCE \
    --signature-policy "$CC_POLICY" \
    --collections-config ./chaincode/asset/collections_config.json \
    --tls \
    --cafile $ORDERER_CA \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/buyer.example.com/peers/peer0.buyer.example.com/tls/ca.crt \
    --peerAddresses localhost:8051 \
    --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/seller.example.com/peers/peer0.seller.example.com/tls/ca.crt \
    || error_exit "Failed to commit chaincode"
echo -e "${GREEN}  ✓ Chaincode committed${NC}"

echo ""
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}✅ Asset chaincode deployed successfully on mychannel!${NC}"
echo -e "${GREEN}============================================================================${NC}"
