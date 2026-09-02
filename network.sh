#!/bin/bash
#
# Fabric Network Management Script
# Simple 2-org network with Buyer and Seller
#

set -e

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/configtx
export VERBOSE=false

# Colors
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'

function infoln()  { echo -e "${C_GREEN}${1}${C_RESET}"; }
function errorln() { echo -e "${C_RED}${1}${C_RESET}"; }
function warnln()  { echo -e "${C_YELLOW}${1}${C_RESET}"; }
function error_exit() { errorln "ERROR: $1"; exit 1; }

function printHelp() {
  echo ""
  echo "Fabric Network Management Script"
  echo "================================="
  echo ""
  echo "Usage: ./network.sh <command>"
  echo ""
  echo "Commands:"
  echo "  all           - Complete deployment (up + createchannel + deploycc)"
  echo "  up            - Start network infrastructure (CA + peers + orderer)"
  echo "  createchannel - Create mychannel and join both peers"
  echo "  deploycc      - Deploy asset chaincode to mychannel"
  echo "  start         - Start stopped containers (preserves state)"
  echo "  stop          - Stop containers (preserves data)"
  echo "  down          - Stop and remove containers (keeps CA data)"
  echo "  cleanall      - Complete cleanup (removes everything)"
  echo "  restart       - Restart network (down + all)"
  echo ""
  echo "Examples:"
  echo "  ./network.sh all        # Full deployment (first time)"
  echo "  ./network.sh stop       # Pause network"
  echo "  ./network.sh start      # Resume network"
  echo "  ./network.sh down       # Stop and cleanup"
  echo "  ./network.sh cleanall   # Complete cleanup"
  echo ""
  echo "Quick Start:"
  echo "  1. ./network.sh all"
  echo "  2. cd gateway-app && node server.js"
  echo ""
  echo "CouchDB UI: http://localhost:7984/_utils (admin/adminpw)"
  echo "Gateway API: http://localhost:3000"
  echo ""
}

# ============================================
# Utility Functions
# ============================================

function clearContainers() {
  infoln "Removing remaining containers..."
  docker ps -a | grep "hyperledger\|couchdb\|ca\." | awk '{print $1}' | xargs docker rm -f 2>/dev/null || true
  docker ps -a | grep "dev-peer" | awk '{print $1}' | xargs docker rm -f 2>/dev/null || true
  infoln "✓ All containers removed"
}

function removeUnwantedImages() {
  infoln "Removing chaincode images..."
  docker images | grep "dev-peer" | awk '{print $3}' | xargs docker rmi -f 2>/dev/null || true
  infoln "✓ Chaincode images removed"
}

function createNetworkIfNeeded() {
  if ! docker network inspect fabric_network >/dev/null 2>&1; then
    infoln "Creating Docker network: fabric_network"
    docker network create fabric_network
  fi
}

# ============================================
# CA Server Functions
# ============================================

function initializeCADirectories() {
  infoln "Initializing CA directories..."
  mkdir -p organizations/fabric-ca/{orderer,buyer,seller}
  infoln "CA directories initialized"
}

function startCAServers() {
  infoln "Starting Fabric CA servers..."

  createNetworkIfNeeded
  initializeCADirectories

  if ! docker-compose -f docker/docker-compose-ca.yaml up -d 2>&1; then
    error_exit "Failed to start CA servers"
  fi

  infoln "Waiting for CA servers to initialize..."
  sleep 15

  local CA_COUNT=$(docker ps | grep "ca\." | wc -l)
  if [ $CA_COUNT -eq 0 ]; then
    error_exit "No CA servers started"
  fi

  infoln "✅ CA servers started ($CA_COUNT containers)"
}

function stopCAServers() {
  infoln "Stopping CA servers..."
  docker-compose -f docker/docker-compose-ca.yaml stop
  infoln "CA servers stopped"
}

function removeCAServers() {
  infoln "Removing CA servers and data..."
  docker-compose -f docker/docker-compose-ca.yaml down --volumes --remove-orphans
  rm -rf organizations/fabric-ca
  infoln "CA servers and data removed"
}

# ============================================
# Certificate Generation
# ============================================

function generateCryptoWithCA() {
  infoln "Generating certificates using Fabric CA..."

  if [ ! -f "./scripts/ca-functions.sh" ]; then
    error_exit "CA functions script not found"
  fi

  source ./scripts/ca-functions.sh

  sleep 5

  infoln "Enrolling certificates for all organizations..."
  echo ""

  createOrdererOrgCerts                          || error_exit "Failed to create orderer certificates"
  createPeerOrgCerts "buyer"  "7154" "buyer.example.com"  || error_exit "Failed to create buyer certificates"
  createPeerOrgCerts "seller" "8054" "seller.example.com" || error_exit "Failed to create seller certificates"

  echo ""
  infoln "✅ All certificates generated"
}

function generateCrypto() {
  if [ -d "organizations/peerOrganizations" ] && [ -d "organizations/ordererOrganizations" ]; then
    infoln "Certificates already exist, skipping generation"
    return 0
  fi

  local CA_COUNT=$(docker ps | grep "ca\." | wc -l)
  if [ $CA_COUNT -lt 3 ]; then
    error_exit "Fabric CA servers not running (found $CA_COUNT, need 3). Cannot generate certificates."
  fi

  generateCryptoWithCA
}

# ============================================
# Network Infrastructure Functions
# ============================================

function startCouchDB() {
  infoln "Starting CouchDB containers..."

  createNetworkIfNeeded

  if ! docker-compose -f docker/docker-compose-couch.yaml up -d --remove-orphans 2>&1; then
    error_exit "Failed to start CouchDB"
  fi

  infoln "Waiting for CouchDB to be ready..."
  sleep 10

  local COUCHDB_COUNT=$(docker ps | grep "couchdb" | wc -l)
  if [ $COUCHDB_COUNT -ne 2 ]; then
    error_exit "Expected 2 CouchDB containers, found $COUCHDB_COUNT"
  fi

  infoln "✅ CouchDB started ($COUCHDB_COUNT containers)"
}

function startNetworkContainers() {
  infoln "Starting network (orderer and peers)..."

  if ! docker-compose -f docker/docker-compose-couch.yaml -f docker/docker-compose-network.yaml up -d --remove-orphans 2>&1; then
    error_exit "Failed to start network"
  fi

  infoln "Waiting for network to be ready..."
  sleep 15

  local ORDERER_COUNT=$(docker ps | grep "orderer\." | wc -l)
  local PEER_COUNT=$(docker ps | grep "peer0\." | wc -l)

  if [ $ORDERER_COUNT -ne 1 ]; then
    error_exit "Expected 1 orderer, found $ORDERER_COUNT"
  fi

  if [ $PEER_COUNT -ne 2 ]; then
    error_exit "Expected 2 peers, found $PEER_COUNT"
  fi

  infoln "✅ Network started ($ORDERER_COUNT orderer, $PEER_COUNT peers)"
}

# ============================================
# Channel and Chaincode Functions
# ============================================

function createChannels() {
  infoln "Creating channels..."

  if [ ! -f "./scripts/deploy-channels.sh" ]; then
    error_exit "scripts/deploy-channels.sh not found"
  fi

  if ! ./scripts/deploy-channels.sh; then
    error_exit "Failed to create channels"
  fi

  infoln "✅ mychannel created successfully"
}

function deployChaincode() {
  infoln "Deploying asset chaincode..."

  if [ ! -f "./scripts/deploy-chaincodes.sh" ]; then
    error_exit "scripts/deploy-chaincodes.sh not found"
  fi

  if ! ./scripts/deploy-chaincodes.sh; then
    error_exit "Failed to deploy chaincode"
  fi

  infoln "✅ Asset chaincode deployed successfully"
}

# ============================================
# Main Network Commands
# ============================================

function networkUp() {
  infoln "================================="
  infoln "Starting Fabric Network"
  infoln "================================="
  echo ""

  if [ "$(docker ps -q -f name=orderer.example.com)" ]; then
    warnln "Network is already running!"
    warnln "Use './network.sh stop' to stop, or './network.sh down' to remove"
    exit 1
  fi

  command -v docker >/dev/null 2>&1           || error_exit "docker not found"
  command -v docker-compose >/dev/null 2>&1   || error_exit "docker-compose not found"
  command -v fabric-ca-client >/dev/null 2>&1 || error_exit "fabric-ca-client not found"

  startCAServers
  generateCrypto
  startCouchDB
  startNetworkContainers

  showNetworkStatus "infrastructure"
}

function networkAll() {
  infoln "================================="
  infoln "Complete Fabric Network Deployment"
  infoln "================================="
  echo ""

  if [ "$(docker ps -q -f name=orderer.example.com)" ]; then
    warnln "Network is already running!"
    warnln "Use './network.sh down' first to redeploy"
    exit 1
  fi

  command -v docker >/dev/null 2>&1           || error_exit "docker not found"
  command -v docker-compose >/dev/null 2>&1   || error_exit "docker-compose not found"
  command -v fabric-ca-client >/dev/null 2>&1 || error_exit "fabric-ca-client not found"
  command -v peer >/dev/null 2>&1             || error_exit "peer not found"
  command -v configtxgen >/dev/null 2>&1      || error_exit "configtxgen not found"
  command -v jq >/dev/null 2>&1               || error_exit "jq not found"

  startCAServers
  generateCrypto
  startCouchDB
  startNetworkContainers
  createChannels
  deployChaincode

  showNetworkStatus "complete"
}

function networkStart() {
  infoln "Starting network with existing state..."

  if [ ! -d "organizations/peerOrganizations" ] || [ ! -d "organizations/ordererOrganizations" ]; then
    errorln "Certificates not found!"
    errorln "Use './network.sh up' to generate new certificates"
    exit 1
  fi

  if [ -d "organizations/fabric-ca" ]; then
    docker-compose -f docker/docker-compose-ca.yaml start 2>/dev/null || true
  fi

  docker-compose -f docker/docker-compose-couch.yaml -f docker/docker-compose-network.yaml start

  infoln "✅ Network started with existing state"
}

function networkStop() {
  infoln "Stopping network containers..."

  docker-compose -f docker/docker-compose-ca.yaml stop 2>/dev/null || true
  docker-compose -f docker/docker-compose-couch.yaml -f docker/docker-compose-network.yaml stop

  infoln "✅ Network stopped (all data preserved)"
  infoln "Use './network.sh start' to resume"
}

function networkDown() {
  infoln "Stopping and removing network containers..."

  docker-compose -f docker/docker-compose-couch.yaml -f docker/docker-compose-network.yaml down --volumes --remove-orphans 2>/dev/null || true

  clearContainers
  removeUnwantedImages

  rm -rf channel-artifacts/*.block
  rm -rf organizations/ordererOrganizations
  rm -rf organizations/peerOrganizations
  rm -rf *.tar.gz

  infoln "✅ Network removed (CA data preserved)"
  warnln "Run './network.sh all' to redeploy"
}

function cleanAll() {
  infoln "Complete cleanup - removing ALL data..."

  docker-compose -f docker/docker-compose-ca.yaml down --volumes --remove-orphans 2>/dev/null || true
  docker-compose -f docker/docker-compose-couch.yaml -f docker/docker-compose-network.yaml down --volumes --remove-orphans 2>/dev/null || true

  clearContainers
  removeUnwantedImages

  infoln "Removing all certificates and CA data..."
  docker run --rm -v ${PWD}/organizations:/organizations alpine \
    sh -c "rm -rf /organizations/fabric-ca /organizations/ordererOrganizations /organizations/peerOrganizations" 2>/dev/null || true
  rm -rf organizations/ordererOrganizations organizations/peerOrganizations organizations/fabric-ca 2>/dev/null || true

  rm -rf channel-artifacts/*.block
  rm -rf *.tar.gz

  infoln "✅ Complete cleanup finished"
  infoln "Run './network.sh all' to start fresh"
}

# ============================================
# Status Display
# ============================================

function showNetworkStatus() {
  local mode=$1

  local ORDERERS=$(docker ps --format "{{.Names}}" | grep "^orderer\." | wc -l)
  local PEERS=$(docker ps --format "{{.Names}}" | grep "^peer0\." | wc -l)
  local COUCHDB=$(docker ps --format "{{.Names}}" | grep "^couchdb\." | wc -l)
  local CA_SERVERS=$(docker ps --format "{{.Names}}" | grep "^ca\." | wc -l)

  echo ""
  infoln "================================="
  infoln "✅ Network Status"
  infoln "================================="
  echo ""
  infoln "  CA servers:  $CA_SERVERS"
  infoln "  Orderers:    $ORDERERS"
  infoln "  Peers:       $PEERS"
  infoln "  CouchDB:     $COUCHDB"
  echo ""
  infoln "CouchDB UI:"
  infoln "  Buyer:   http://localhost:7984/_utils"
  infoln "  Seller:  http://localhost:8984/_utils"
  echo ""

  if [ "$mode" == "infrastructure" ]; then
    infoln "Next steps:"
    infoln "  ./network.sh createchannel   # Create mychannel"
    infoln "  ./network.sh deploycc        # Deploy asset chaincode"
    echo ""
  elif [ "$mode" == "complete" ]; then
    infoln "✅ Deployment complete!"
    echo ""
    infoln "  Channel:    mychannel"
    infoln "  Chaincode:  asset"
    infoln "  Orgs:       Buyer + Seller"
    echo ""
    infoln "Start the gateway:"
    infoln "  cd gateway-app && node server.js"
    infoln "  API: http://localhost:3000"
    echo ""
  fi
}

# ============================================
# Command Routing
# ============================================

if [[ $# -lt 1 ]]; then
  printHelp
  exit 0
fi

MODE=$1
shift

while [[ $# -ge 1 ]]; do
  key="$1"
  case $key in
    -h | --help) printHelp; exit 0 ;;
    -verbose) VERBOSE=true ;;
    *) errorln "Unknown flag: $key"; printHelp; exit 1 ;;
  esac
  shift
done

case "${MODE}" in
  up)            networkUp ;;
  all)           networkAll ;;
  createchannel | createChannel | channels)
    [ ! "$(docker ps -q -f name=orderer.example.com)" ] && error_exit "Network not running. Run './network.sh up' first"
    createChannels ;;
  deploycc | deploy | deployCC)
    [ ! "$(docker ps -q -f name=orderer.example.com)" ] && error_exit "Network not running. Run './network.sh up' first"
    deployChaincode ;;
  start)         networkStart ;;
  stop)          networkStop ;;
  down)          networkDown ;;
  cleanall | clean) cleanAll ;;
  restart)       networkDown; sleep 2; networkAll ;;
  *)             errorln "Unknown command: ${MODE}"; printHelp; exit 1 ;;
esac
