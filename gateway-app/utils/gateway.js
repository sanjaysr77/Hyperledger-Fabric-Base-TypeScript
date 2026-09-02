/**
 * Gateway Connection Utility for Hyperledger Fabric 2.5.x
 * Replaces the old fabric-client SDK with fabric-gateway
 */

// CRITICAL: Disable TLS certificate verification for development
// Must be set before requiring grpc module
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const grpc = require('@grpc/grpc-js');
const { connect, signers } = require('@hyperledger/fabric-gateway');
const { getOrgPort } = require('../config/networkTopology');
const crypto = require('crypto');
const fs = require('fs').promises;
const path = require('path');

// Connection configuration
const config = {
    channelName: 'mychannel',
    chaincodeName: 'asset',
    cryptoPath: path.resolve(__dirname, '../../organizations/peerOrganizations'),
};

/**
 * Get peer endpoint for organization
 * Uses localhost since the gRPC client runs on the host, not inside Docker.
 */
function getPeerEndpoint(orgName) {
    const orgNameLower = orgName.toLowerCase();
    const port = getOrgPort(orgNameLower); // throws if unknown org
    return `localhost:${port}`;
}

/**
 * Create a gRPC client connection to the Gateway peer
 */
async function newGrpcConnection(orgName) {
    const orgNameLower = orgName.toLowerCase();

    const tlsDir = path.join(
        config.cryptoPath,
        `${orgNameLower}.example.com`,
        'peers',
        `peer0.${orgNameLower}.example.com`,
        'tls'
    );

    const tlsRootCert = await fs.readFile(path.join(tlsDir, 'ca.crt'));
    const tlsCredentials = grpc.credentials.createSsl(tlsRootCert);

    const peerEndpoint = getPeerEndpoint(orgName);
    const peerHostAlias = `peer0.${orgNameLower}.example.com`;

    console.log(`[Gateway] Connecting to ${peerEndpoint} as ${peerHostAlias}`);

    return new grpc.Client(peerEndpoint, tlsCredentials, {
        'grpc.ssl_target_name_override': peerHostAlias,
    });
}

/**
 * Create a new identity for the user
 */
async function newIdentity(orgName, userId) {
    const orgNameLower = orgName.toLowerCase();

    // Capitalize first letter: buyer -> BuyerMSP
    const mspId = `${orgName.charAt(0).toUpperCase() + orgName.slice(1)}MSP`;

    const certDir = path.join(
        config.cryptoPath,
        `${orgNameLower}.example.com`,
        'users',
        `${userId}@${orgNameLower}.example.com`,
        'msp',
        'signcerts'
    );

    const files = await fs.readdir(certDir);
    const certFile = files.find(file => file.endsWith('.pem'));

    if (!certFile) {
        throw new Error(`No certificate found in ${certDir}`);
    }

    const credentials = await fs.readFile(path.join(certDir, certFile));
    return { mspId, credentials };
}

/**
 * Create a new signer for the user
 */
async function newSigner(orgName, userId) {
    const orgNameLower = orgName.toLowerCase();

    const keyPath = path.join(
        config.cryptoPath,
        `${orgNameLower}.example.com`,
        'users',
        `${userId}@${orgNameLower}.example.com`,
        'msp',
        'keystore'
    );

    const files = await fs.readdir(keyPath);
    const keyFile = files.find(file => file.endsWith('_sk'));

    if (!keyFile) {
        throw new Error(`No private key found in ${keyPath}`);
    }

    const privateKeyPem = await fs.readFile(path.join(keyPath, keyFile));
    const privateKey = crypto.createPrivateKey(privateKeyPem);

    return signers.newPrivateKeySigner(privateKey);
}

/**
 * Connect to the Gateway and return a network instance
 */
async function connectGateway(orgName, userId, channelName) {
    const client = await newGrpcConnection(orgName);

    // Always use 'Admin' Fabric CA identity for gateway connection.
    // MongoDB application users are not enrolled with the Fabric CA.
    const fabricIdentity = 'Admin';
    const gatewayIdentity = await newIdentity(orgName, fabricIdentity);
    const gatewaySigner = await newSigner(orgName, fabricIdentity);

    // Override discovered peer endpoints to use localhost since we're on the host machine.
    // Service discovery returns internal Docker hostnames which don't resolve outside Docker.

    const gateway = connect({
        client,
        identity: gatewayIdentity,
        signer: gatewaySigner,
        evaluateOptions: () => {
            return { deadline: Date.now() + 10000 }; // 10 seconds
        },
        endorseOptions: () => {
            return { deadline: Date.now() + 30000 }; // 30 seconds
        },
        submitOptions: () => {
            return { deadline: Date.now() + 10000 }; // 10 seconds
        },
        commitStatusOptions: () => {
            return { deadline: Date.now() + 120000 }; // 2 minutes
        },
    });

    return gateway.getNetwork(channelName);
}

/**
 * Submit a transaction to the ledger
 */
async function submitTransaction(orgName, userId, channelName, chaincodeName, functionName, ...args) {
    try {
        const network = await connectGateway(orgName, userId, channelName);
        const contract = network.getContract(chaincodeName);

        const resultBytes = await contract.submitTransaction(functionName, ...args);
        const resultString = utf8Decoder.decode(resultBytes);

        try {
            return JSON.parse(resultString);
        } catch (e) {
            return resultString;
        }
    } catch (error) {
        console.error('Failed to submit transaction:', error);
        throw error;
    }
}

/**
 * Evaluate a transaction (query) without submitting to the ledger
 */
async function evaluateTransaction(orgName, userId, channelName, chaincodeName, functionName, ...args) {
    let opts = {};
    if (args.length > 0 && args[args.length - 1] !== null && typeof args[args.length - 1] === 'object' && !Array.isArray(args[args.length - 1]) && args[args.length - 1].__gatewayOpts) {
        opts = args.pop();
    }
    try {
        const network = await connectGateway(orgName, userId, channelName);
        const contract = network.getContract(chaincodeName);

        const resultBytes = await contract.evaluateTransaction(functionName, ...args);
        const resultString = utf8Decoder.decode(resultBytes);

        try {
            return JSON.parse(resultString);
        } catch (e) {
            return resultString;
        }
    } catch (error) {
        if (!opts.silent) console.error('Failed to evaluate transaction:', error);
        throw error;
    }
}

/**
 * Listen for chaincode events
 */
async function listenForEvents(orgName, userId, channelName, chaincodeName, eventName, callback) {
    try {
        const network = await connectGateway(orgName, userId, channelName);
        const events = await network.getChaincodeEvents(chaincodeName);

        for await (const event of events) {
            if (event.eventName === eventName) {
                const payload = JSON.parse(event.payload.toString());
                callback(payload);
            }
        }
    } catch (error) {
        console.error('Failed to listen for events:', error);
        throw error;
    }
}

const utf8Decoder = new TextDecoder();

module.exports = {
    connectGateway,
    submitTransaction,
    evaluateTransaction,
    listenForEvents,
    config,
};
