const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// Public routes
router.post('/login', authController.login);
router.post('/register', authController.register);
router.get('/verify', authController.verifyToken);

// Protected routes
router.get('/navigation', authController.authenticate, authController.getNavigation);

module.exports = router;
