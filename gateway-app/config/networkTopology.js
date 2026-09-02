'use strict';

/**
 * Network Topology — single source of truth.
 *
 * To add a new organisation (e.g. "buyer2"):
 *   1. Add an entry below with port, channels, partners.
 *   2. That's it — no other file needs to change.
 *
 * Schema per entry:
 *   port      {number}   gRPC peer port
 *   channels  {string[]} all channels this org participates in
 *   partners  { [orgName]: { channel, msp } }  direct trading partners
 */
const TOPOLOGY = {
    buyer: {
        port: 7051,
        channels: ['mychannel'],
        partners: {
            seller: { channel: 'mychannel', msp: 'SellerMSP' },
        },
    },
    seller: {
        port: 8051,
        channels: ['mychannel'],
        partners: {
            buyer: { channel: 'mychannel', msp: 'BuyerMSP' },
        },
    },
};

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Normalise org name: strip MSP suffix, lowercase. */
function _key(orgName) {
    return (orgName || '').toLowerCase().replace(/msp$/i, '');
}

/** Get topology entry for an org (null if unknown). */
function getOrgConfig(orgName) {
    return TOPOLOGY[_key(orgName)] || null;
}

/** All channels this org participates in. */
function getOrgChannels(orgName) {
    return getOrgConfig(orgName)?.channels || [];
}

/** gRPC peer port for this org. Throws if unknown. */
function getOrgPort(orgName) {
    const cfg = getOrgConfig(orgName);
    if (!cfg) throw new Error(`Unknown organisation: "${orgName}". Add it to networkTopology.js.`);
    return cfg.port;
}

/**
 * Channel shared between two orgs (pass org names or MSP IDs).
 * Returns null if no shared channel exists.
 */
function getChannelBetween(org1, org2) {
    const a = _key(org1);
    const b = _key(org2);
    return TOPOLOGY[a]?.partners?.[b]?.channel
        || TOPOLOGY[b]?.partners?.[a]?.channel
        || null;
}

/**
 * Trading partners for an org.
 * Returns [{ value: msp, label, channel }]
 */
function getOrgPartners(orgName) {
    const cfg = getOrgConfig(orgName);
    if (!cfg?.partners) return [];
    return Object.entries(cfg.partners).map(([name, info]) => ({
        value:   info.msp,
        label:   name.charAt(0).toUpperCase() + name.slice(1),
        channel: info.channel,
    }));
}

/** All org names known to the topology. */
function getAllOrgNames() {
    return Object.keys(TOPOLOGY);
}

/**
 * Other orgs that share a given channel with the specified org.
 * Returns string[] of org names (lowercase).
 */
function getChannelPartners(channelName, orgName) {
    const self = _key(orgName);
    return Object.keys(TOPOLOGY).filter(name =>
        name !== self && TOPOLOGY[name].channels.includes(channelName)
    );
}

/**
 * Normalise an orgType string by stripping trailing digits.
 * "buyer1" → "buyer"
 */
function normalizeOrgType(orgType) {
    return (orgType || '').toLowerCase().replace(/\d+$/, '');
}

module.exports = {
    TOPOLOGY,
    getOrgConfig,
    getOrgChannels,
    getOrgPort,
    getChannelBetween,
    getOrgPartners,
    getAllOrgNames,
    getChannelPartners,
    normalizeOrgType,
};
