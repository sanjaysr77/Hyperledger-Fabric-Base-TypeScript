/**
 * User Routes with RBAC
 */

const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const { authorize, logAccess, requireBlockchainAccess } = require('../middleware/rbac');
const { ROLES } = require('../constants/roles');

// Apply access logging
router.use(logAccess);

// Apply blockchain access check (blocks SuperAdmin)
router.use(requireBlockchainAccess);

// Create user - Admin only (SuperAdmin uses MongoDB endpoints)
router.post('/users', authorize(
    ROLES.ADMIN
), userController.createUser);

// Create admin - Admin only (SuperAdmin uses MongoDB endpoints)
router.post('/admins', authorize(
    ROLES.ADMIN
), userController.createAdmin);

// Create organization - Admin only (SuperAdmin uses MongoDB endpoints)
router.post('/organizations', authorize(
    ROLES.ADMIN
), userController.createOrganization);

// Get users count - Admin only
router.get('/users/count', authorize(ROLES.ADMIN), userController.getUsersCount);

// Get users by org - Admin only
router.get('/users/org/:orgId', authorize(ROLES.ADMIN), userController.getUsersByOrg);

// Get user - All authenticated users
router.get('/users/:username', userController.getUser);

// Update user profile picture - All authenticated users
router.put('/users/:username/pic', userController.updateProfilePic);

// Update user - All authenticated users (can update their own profile)
router.put('/users/:username', userController.updateUser);

// Get all users - Admin only
router.get('/users', authorize(
    ROLES.ADMIN
), userController.getAllUsers);

// Delete user - Admin only
router.delete('/users/:username', authorize(
    ROLES.ADMIN
), userController.deleteUser);

module.exports = router;
