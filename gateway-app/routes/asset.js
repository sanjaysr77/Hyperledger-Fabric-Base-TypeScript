const express = require('express');
const router = express.Router();
const assetController = require('../controllers/assetController');

// POST   /api/asset        — create asset
router.post('/', assetController.createAsset);

// GET    /api/asset        — get all assets
router.get('/', assetController.getAllAssets);

// GET    /api/asset/:assetId        — get single asset
router.get('/:assetId', assetController.getAsset);

// PUT    /api/asset/:assetId        — update asset
router.put('/:assetId', assetController.updateAsset);

// DELETE /api/asset/:assetId        — delete asset
router.delete('/:assetId', assetController.deleteAsset);

// GET    /api/asset/:assetId/history — get asset history
router.get('/:assetId/history', assetController.getAssetHistory);

module.exports = router;
