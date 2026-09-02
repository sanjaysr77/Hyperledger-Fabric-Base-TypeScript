#!/bin/bash

# ============================================================================
# SET ANCHOR PEERS FOR MYCHANNEL
# Run from the project root directory
# ============================================================================

export PATH=${PWD}/../bin:${PATH}
export FABRIC_CFG_PATH=${PWD}/config
export CORE_PEER_TLS_ENABLED=true

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

command -v peer >/dev/null 2>&1          || { echo -e "${RED}ERROR: peer not found${NC}"; exit 1; }
command -v configtxlator >/dev/null 2>&1 || { echo -e "${RED}ERROR: configtxlator not found${NC}"; exit 1; }
command -v jq >/dev/null 2>&1            || { echo -e "${RED}ERROR: jq not found${NC}"; exit 1; }

setPeerEnv() {
    local ORG=$1 MSP=$2 PORT=$3
    export CORE_PEER_LOCALMSPID="$MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${ORG}.example.com/peers/peer0.${ORG}.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${ORG}.example.com/users/Admin@${ORG}.example.com/msp
    export CORE_PEER_ADDRESS=peer0.${ORG}.example.com:${PORT}
}

setAnchorPeer() {
    local ORG=$1 MSP=$2 PORT=$3 CHANNEL=$4
    local HOST="peer0.${ORG}.example.com"

    echo -e "${BLUE}  ${MSP} → ${CHANNEL}...${NC}"
    setPeerEnv "$ORG" "$MSP" "$PORT"

    peer channel fetch config /tmp/config_block.pb \
        -o orderer.example.com:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        -c "$CHANNEL" --tls --cafile "$ORDERER_CA" >/dev/null 2>&1

    configtxlator proto_decode --input /tmp/config_block.pb \
        --type common.Block 2>/dev/null | \
        jq .data.data[0].payload.data.config > /tmp/config.json

    jq --arg HOST "$HOST" --argjson PORT "$PORT" --arg MSP "$MSP" \
        '.channel_group.groups.Application.groups[$MSP].values.AnchorPeers = {
            "mod_policy": "Admins",
            "value": { "anchor_peers": [{ "host": $HOST, "port": $PORT }] },
            "version": "0"
        }' /tmp/config.json > /tmp/modified_config.json

    configtxlator proto_encode --input /tmp/config.json \
        --type common.Config --output /tmp/config.pb 2>/dev/null
    configtxlator proto_encode --input /tmp/modified_config.json \
        --type common.Config --output /tmp/modified_config.pb 2>/dev/null

    if ! configtxlator compute_update \
        --channel_id "$CHANNEL" \
        --original /tmp/config.pb \
        --updated /tmp/modified_config.pb \
        --output /tmp/config_update.pb 2>/dev/null; then
        echo -e "${YELLOW}    ⚠ Already set${NC}"
        return 0
    fi

    configtxlator proto_decode --input /tmp/config_update.pb \
        --type common.ConfigUpdate --output /tmp/config_update.json 2>/dev/null

    echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"$CHANNEL\",\"type\":2}},\"data\":{\"config_update\":$(cat /tmp/config_update.json)}}}" | \
        configtxlator proto_encode --type common.Envelope \
        --output /tmp/anchor_update.pb 2>/dev/null

    if peer channel update \
        -f /tmp/anchor_update.pb -c "$CHANNEL" \
        -o orderer.example.com:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile "$ORDERER_CA" 2>/dev/null; then
        echo -e "${GREEN}    ✓ Set${NC}"
    else
        echo -e "${RED}    ✗ Failed${NC}"
    fi
}

echo "============================================================================"
echo "Setting Anchor Peers for mychannel"
echo "============================================================================"

echo -e "\n${YELLOW}mychannel${NC}"
setAnchorPeer "buyer"  "BuyerMSP"  7051 "mychannel"
setAnchorPeer "seller" "SellerMSP" 8051 "mychannel"

echo ""
echo -e "${GREEN}============================================================================"
echo "✅ Done. Gossip membership will populate within ~30 seconds."
echo "============================================================================${NC}"
