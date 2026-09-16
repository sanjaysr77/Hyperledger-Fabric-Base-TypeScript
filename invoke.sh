#!/bin/bash
# Helper script to invoke chaincode from inside the peer container

set -e

CHANNEL=${1:-kyctokenchannel}
CHAINCODE=${2:-kyc-token-cc}
FUNCTION=$3
shift 3
ARGS="$@"

if [ -z "$FUNCTION" ]; then
  echo "Usage: ./invoke.sh [channel] [chaincode] <function> <arg1> <arg2> ..."
  echo ""
  echo "Example:"
  echo "  ./invoke.sh kyctokenchannel kyc-token-cc RecordConsent consent-001 customer-001 GIVEN"
  exit 1
fi

# Build the args JSON
ARGS_JSON="["
FIRST=true
for arg in $ARGS; do
  if [ "$FIRST" = true ]; then
    ARGS_JSON="$ARGS_JSON\"$arg\""
    FIRST=false
  else
    ARGS_JSON="$ARGS_JSON,\"$arg\""
  fi
done
ARGS_JSON="$ARGS_JSON]"

echo "Invoking: function=$FUNCTION, channel=$CHANNEL, chaincode=$CHAINCODE"
echo "Args: $ARGS_JSON"
echo ""

docker exec \
  -e FABRIC_CFG_PATH=/etc/hyperledger/peercfg \
  -e CORE_PEER_TLS_ENABLED=true \
  -e CORE_PEER_LOCALMSPID=Org1MSP \
  -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp \
  -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 \
  peer0.org1.example.com \
  peer chaincode invoke \
  -C "$CHANNEL" \
  -n "$CHAINCODE" \
  -c "{\"function\":\"$FUNCTION\",\"Args\":$ARGS_JSON}" \
  --tls \
  -o orderer.example.com:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tlsRootCertFiles /etc/hyperledger/orderer/tls/ca.crt 2>&1 | grep -v "Failed loading\|WARN"

