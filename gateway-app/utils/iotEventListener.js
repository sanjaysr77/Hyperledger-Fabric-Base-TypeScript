/**
 * Blockchain Event Listener
 * Listens for events emitted by the asset chaincode and stores them in memory.
 */

const { connectGateway } = require('./gateway');

const MAX_EVENTS = 200;
const recentEvents = [];

const WATCHED_EVENTS = new Set([
    'AssetCreated',
    'AssetUpdated',
    'AssetDeleted',
]);

const EVENT_META = {
    AssetCreated: { type: 'info',    title: 'Asset Created' },
    AssetUpdated: { type: 'info',    title: 'Asset Updated' },
    AssetDeleted: { type: 'warning', title: 'Asset Deleted' },
};

async function startEventListener(orgName, userId, channelName) {
    try {
        const network = await connectGateway(orgName, userId, channelName);
        const events = await network.getChaincodeEvents('asset');

        (async () => {
            try {
                for await (const event of events) {
                    if (!WATCHED_EVENTS.has(event.eventName)) continue;

                    const meta = EVENT_META[event.eventName] || { type: 'info', title: event.eventName };
                    const assetId = event.payload ? event.payload.toString() : 'unknown';

                    const entry = {
                        id: `${event.eventName}-${event.transactionId || Date.now()}`,
                        type: meta.type,
                        title: meta.title,
                        eventName: event.eventName,
                        assetId,
                        txId: event.transactionId,
                        blockNumber: event.blockNumber?.toString(),
                        timestamp: new Date().toISOString(),
                        message: `Asset ${assetId} — ${meta.title}`,
                    };

                    // Deduplicate by id
                    if (!recentEvents.find(e => e.id === entry.id)) {
                        recentEvents.unshift(entry);
                        if (recentEvents.length > MAX_EVENTS) recentEvents.pop();
                    }
                }
            } catch (err) {
                setTimeout(() => startEventListener(orgName, userId, channelName), 15000);
            }
        })();
    } catch (err) {
        setTimeout(() => startEventListener(orgName, userId, channelName), 30000);
    }
}

function getRecentEvents() {
    return recentEvents;
}

module.exports = { startEventListener, getRecentEvents };
