#!/bin/bash
#
# Fabric CA Helper Functions
#

# Function to create peer organization certificates
createPeerOrgCerts() {
    local ORG=$1
    local CA_PORT=$2
    local ORG_DOMAIN=$3

    echo "Creating certificates for $ORG..."

    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}

    # Wait for CA to generate TLS cert
    echo "  Waiting for CA TLS certificate..."
    local MAX_WAIT=30
    local WAIT_COUNT=0
    while [ ! -f "${PWD}/organizations/fabric-ca/${ORG}/tls-cert.pem" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done

    if [ ! -f "${PWD}/organizations/fabric-ca/${ORG}/tls-cert.pem" ]; then
        echo "    ERROR: CA TLS certificate not found for ${ORG}"
        return 1
    fi

    # Enroll CA admin
    echo "  Enrolling CA admin..."
    if ! fabric-ca-client enroll -u https://admin:adminpw@localhost:${CA_PORT} --caname ca.${ORG_DOMAIN} --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG}/tls-cert.pem >/dev/null 2>&1; then
        echo "    ERROR: Failed to enroll CA admin for ${ORG}"
        return 1
    fi

    # Create config.yaml for NodeOUs
    echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: orderer' > ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/msp/config.yaml

    # Copy CA cert to standard location for config.yaml reference
    mkdir -p ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/msp/cacerts
    cp ${PWD}/organizations/fabric-ca/${ORG}/ca-cert.pem ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/msp/cacerts/ca.crt 2>/dev/null || \
    cp ${PWD}/organizations/fabric-ca/${ORG}/msp/cacerts/* ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/msp/cacerts/ca.crt 2>/dev/null || true

    # Register identities
    echo "  Registering peer..."
    fabric-ca-client register --caname ca.${ORG_DOMAIN} --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG}/tls-cert.pem >/dev/null 2>&1

    echo "  Registering user..."
    fabric-ca-client register --caname ca.${ORG_DOMAIN} --id.name user1 --id.secret user1pw --id.type client --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG}/tls-cert.pem >/dev/null 2>&1

    echo "  Registering admin..."
    fabric-ca-client register --caname ca.${ORG_DOMAIN} --id.name ${ORG}admin --id.secret ${ORG}adminpw --id.type admin --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG}/tls-cert.pem >/dev/null 2>&1

    # Enroll peer
    echo "  Enrolling peer..."
    mkdir -p ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}

    fabric-ca-client enroll -u https://peer0:peer0pw@localhost:${CA_PORT} --caname ca.${ORG_DOMAIN} -M ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/msp --csr.hosts peer0.${ORG_DOMAIN} --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG}/tls-cert.pem >/dev/null 2>&1

    cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/msp/config.yaml ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/msp/config.yaml

    # Enroll peer TLS
    echo "  Enrolling peer TLS..."
    fabric-ca-client enroll -u https://peer0:peer0pw@localhost:${CA_PORT} --caname ca.${ORG_DOMAIN} -M ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls --enrollment.profile tls --csr.hosts peer0.${ORG_DOMAIN} --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG}/tls-cert.pem >/dev/null 2>&1

    cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls/ca.crt
    cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls/signcerts/* ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls/server.crt
    cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls/keystore/* ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls/server.key

    mkdir -p ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls/tlscacerts

    # Enroll user
    echo "  Enrolling user..."
    mkdir -p ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/users/User1@${ORG_DOMAIN}

    fabric-ca-client enroll -u https://user1:user1pw@localhost:${CA_PORT} --caname ca.${ORG_DOMAIN} -M ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/users/User1@${ORG_DOMAIN}/msp --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG}/tls-cert.pem >/dev/null 2>&1

    cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/msp/config.yaml ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/users/User1@${ORG_DOMAIN}/msp/config.yaml
    cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/msp/cacerts/ca.crt ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/users/User1@${ORG_DOMAIN}/msp/cacerts/ca.crt 2>/dev/null || true

    # Enroll admin
    echo "  Enrolling admin..."
    mkdir -p ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/users/Admin@${ORG_DOMAIN}

    fabric-ca-client enroll -u https://${ORG}admin:${ORG}adminpw@localhost:${CA_PORT} --caname ca.${ORG_DOMAIN} -M ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/users/Admin@${ORG_DOMAIN}/msp --tls.certfiles ${PWD}/organizations/fabric-ca/${ORG}/tls-cert.pem >/dev/null 2>&1

    cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/msp/config.yaml ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/users/Admin@${ORG_DOMAIN}/msp/config.yaml
    cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/msp/cacerts/ca.crt ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/users/Admin@${ORG_DOMAIN}/msp/cacerts/ca.crt 2>/dev/null || true

    # Create org MSP structure
    mkdir -p ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/msp/tlscacerts
    cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/msp/tlscacerts/ca.crt

    mkdir -p ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/tlsca
    cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/tlsca/tlsca.${ORG_DOMAIN}-cert.pem

    mkdir -p ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/ca
    cp ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/peer0.${ORG_DOMAIN}/msp/cacerts/* ${PWD}/organizations/peerOrganizations/${ORG_DOMAIN}/ca/ca.${ORG_DOMAIN}-cert.pem

    echo "  ✅ $ORG certificates created"
}

# Function to create orderer organization certificates
createOrdererOrgCerts() {
    echo "Creating certificates for Orderer organization..."

    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrganizations/example.com

    # Wait for CA to generate TLS cert
    echo "  Waiting for CA TLS certificate..."
    local MAX_WAIT=30
    local WAIT_COUNT=0
    while [ ! -f "${PWD}/organizations/fabric-ca/orderer/tls-cert.pem" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done

    if [ ! -f "${PWD}/organizations/fabric-ca/orderer/tls-cert.pem" ]; then
        echo "    ERROR: CA TLS certificate not found"
        return 1
    fi

    # Enroll CA admin
    echo "  Enrolling CA admin..."
    if ! fabric-ca-client enroll -u https://admin:adminpw@localhost:7054 --caname ca.orderer.example.com --tls.certfiles ${PWD}/organizations/fabric-ca/orderer/tls-cert.pem >/dev/null 2>&1; then
        echo "    ERROR: Failed to enroll CA admin for orderer"
        return 1
    fi

    # Create config.yaml
    echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: orderer' > ${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml

    # Copy CA cert
    mkdir -p ${PWD}/organizations/ordererOrganizations/example.com/msp/cacerts
    cp ${PWD}/organizations/fabric-ca/orderer/ca-cert.pem ${PWD}/organizations/ordererOrganizations/example.com/msp/cacerts/ca.crt 2>/dev/null || \
    cp ${PWD}/organizations/fabric-ca/orderer/msp/cacerts/* ${PWD}/organizations/ordererOrganizations/example.com/msp/cacerts/ca.crt 2>/dev/null || true

    # Register orderer and admin
    echo "  Registering orderer..."
    fabric-ca-client register --caname ca.orderer.example.com --id.name orderer --id.secret ordererpw --id.type orderer --tls.certfiles ${PWD}/organizations/fabric-ca/orderer/tls-cert.pem >/dev/null 2>&1

    echo "  Registering admin..."
    fabric-ca-client register --caname ca.orderer.example.com --id.name ordererAdmin --id.secret ordererAdminpw --id.type admin --tls.certfiles ${PWD}/organizations/fabric-ca/orderer/tls-cert.pem >/dev/null 2>&1

    # Enroll orderer
    echo "  Enrolling orderer..."
    mkdir -p ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com

    fabric-ca-client enroll -u https://orderer:ordererpw@localhost:7054 --caname ca.orderer.example.com -M ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp --csr.hosts orderer.example.com --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/orderer/tls-cert.pem >/dev/null 2>&1

    cp ${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/config.yaml

    fabric-ca-client enroll -u https://orderer:ordererpw@localhost:7054 --caname ca.orderer.example.com -M ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls --enrollment.profile tls --csr.hosts orderer.example.com --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/orderer/tls-cert.pem >/dev/null 2>&1

    cp ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/* ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
    cp ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/signcerts/* ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
    cp ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/keystore/* ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

    mkdir -p ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts
    cp ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/* ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

    # Enroll admin
    echo "  Enrolling admin..."
    mkdir -p ${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com

    fabric-ca-client enroll -u https://ordererAdmin:ordererAdminpw@localhost:7054 --caname ca.orderer.example.com -M ${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp --tls.certfiles ${PWD}/organizations/fabric-ca/orderer/tls-cert.pem >/dev/null 2>&1

    cp ${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml ${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp/config.yaml
    cp ${PWD}/organizations/ordererOrganizations/example.com/msp/cacerts/ca.crt ${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp/cacerts/ca.crt 2>/dev/null || true

    # Create org MSP structure
    mkdir -p ${PWD}/organizations/ordererOrganizations/example.com/msp/tlscacerts
    cp ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/* ${PWD}/organizations/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem

    mkdir -p ${PWD}/organizations/ordererOrganizations/example.com/tlsca
    cp ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/* ${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

    echo "  ✅ Orderer certificates created"
}
