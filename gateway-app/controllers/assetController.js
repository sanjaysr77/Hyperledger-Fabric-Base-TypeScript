const { submitTransaction, evaluateTransaction } = require('../utils/gateway');

const CHANNEL = 'mychannel';
const CHAINCODE = 'asset';

// Create asset
exports.createAsset = async (req, res) => {
    try {
        const { assetId, name, description, owner, status, value } = req.body;

        if (!assetId || !name) {
            return res.status(400).json({
                success: false,
                message: 'assetId and name are required'
            });
        }

        await submitTransaction(
            req.user.organization,
            req.user.userId,
            CHANNEL,
            CHAINCODE,
            'CreateAsset',
            String(assetId),
            String(name),
            String(description || ''),
            String(owner || req.user.organization),
            String(status || 'Active'),
            String(value || '0')
        );

        res.status(201).json({
            success: true,
            message: 'Asset created successfully'
        });
    } catch (error) {
        console.error('Error creating asset:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to create asset',
            error: error.message
        });
    }
};

// Read asset
exports.getAsset = async (req, res) => {
    try {
        const { assetId } = req.params;

        const result = await evaluateTransaction(
            req.user.organization,
            req.user.userId,
            CHANNEL,
            CHAINCODE,
            'ReadAsset',
            assetId
        );

        res.json({
            success: true,
            data: typeof result === 'string' ? JSON.parse(result) : result
        });
    } catch (error) {
        console.error('Error reading asset:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to read asset',
            error: error.message
        });
    }
};

// Update asset
exports.updateAsset = async (req, res) => {
    try {
        const { assetId } = req.params;
        const { name, description, owner, status, value } = req.body;

        await submitTransaction(
            req.user.organization,
            req.user.userId,
            CHANNEL,
            CHAINCODE,
            'UpdateAsset',
            String(assetId),
            String(name || ''),
            String(description || ''),
            String(owner || ''),
            String(status || ''),
            String(value || '0')
        );

        res.json({
            success: true,
            message: 'Asset updated successfully'
        });
    } catch (error) {
        console.error('Error updating asset:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update asset',
            error: error.message
        });
    }
};

// Delete asset
exports.deleteAsset = async (req, res) => {
    try {
        const { assetId } = req.params;

        await submitTransaction(
            req.user.organization,
            req.user.userId,
            CHANNEL,
            CHAINCODE,
            'DeleteAsset',
            assetId
        );

        res.json({
            success: true,
            message: 'Asset deleted successfully'
        });
    } catch (error) {
        console.error('Error deleting asset:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to delete asset',
            error: error.message
        });
    }
};

// Get all assets
exports.getAllAssets = async (req, res) => {
    try {
        const result = await evaluateTransaction(
            req.user.organization,
            req.user.userId,
            CHANNEL,
            CHAINCODE,
            'GetAllAssets'
        );

        res.json({
            success: true,
            data: typeof result === 'string' ? JSON.parse(result) : result
        });
    } catch (error) {
        console.error('Error getting all assets:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to get assets',
            error: error.message
        });
    }
};

// Get asset history
exports.getAssetHistory = async (req, res) => {
    try {
        const { assetId } = req.params;

        const result = await evaluateTransaction(
            req.user.organization,
            req.user.userId,
            CHANNEL,
            CHAINCODE,
            'GetAssetHistory',
            assetId
        );

        res.json({
            success: true,
            data: typeof result === 'string' ? JSON.parse(result) : result
        });
    } catch (error) {
        console.error('Error getting asset history:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to get asset history',
            error: error.message
        });
    }
};
