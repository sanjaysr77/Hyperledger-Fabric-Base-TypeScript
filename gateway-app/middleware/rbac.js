/**
 * Role-Based Access Control (RBAC) Middleware
 * Implements permission checking for protected routes
 */

const { ROLES, hasPermission, isSuperAdmin, canAccessBlockchain } = require('../constants/roles');

/**
 * Middleware to check if user has required role(s)
 * Usage: router.get('/path', authenticate, authorize(ROLES.ADMIN, ROLES.SUPERADMIN), handler)
 */
const authorize = (...allowedRoles) => {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({
                success: false,
                message: 'Unauthorized - No user found'
            });
        }

        const userRole = req.user.role;
        
        // Check if user's role is in the allowed roles
        if (allowedRoles.includes(userRole)) {
            return next();
        }
        
        // SuperAdmin has access to everything
        if (isSuperAdmin(userRole)) {
            return next();
        }
        
        return res.status(403).json({
            success: false,
            message: 'Forbidden - Insufficient permissions',
            requiredRoles: allowedRoles,
            userRole: userRole
        });
    };
};

/**
 * Middleware to check if user has specific permission
 * Usage: router.post('/path', authenticate, checkPermission('create_po'), handler)
 */
const checkPermission = (permission) => {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({
                success: false,
                message: 'Unauthorized - No user found'
            });
        }

        const userRole = req.user.role;
        
        if (hasPermission(userRole, permission)) {
            return next();
        }
        
        return res.status(403).json({
            success: false,
            message: 'Forbidden - Missing required permission',
            requiredPermission: permission,
            userRole: userRole
        });
    };
};

/**
 * Middleware to check if user belongs to specific organization
 * Usage: router.get('/path', authenticate, checkOrganization, handler)
 */
const checkOrganization = (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({
            success: false,
            message: 'Unauthorized - No user found'
        });
    }

    const userOrg = req.user.orgName;
    const requestedOrg = req.params.organization || req.body.organization || req.query.organization;
    
    // SuperAdmin can access all organizations
    if (isSuperAdmin(req.user.role)) {
        return next();
    }
    
    // Check if user is accessing their own organization
    if (requestedOrg && userOrg !== requestedOrg) {
        return res.status(403).json({
            success: false,
            message: 'Forbidden - Cannot access other organization data',
            userOrganization: userOrg,
            requestedOrganization: requestedOrg
        });
    }
    
    next();
};

/**
 * Middleware to check if user can manage inventory
 */
const canManageInventory = (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({
            success: false,
            message: 'Unauthorized'
        });
    }

    const allowedRoles = [
        ROLES.SUPERADMIN,
        ROLES.ADMIN,
        ROLES.INVENTORY_CONTROLLER,
        ROLES.INVENTORY_MANAGER
    ];

    if (allowedRoles.includes(req.user.role)) {
        return next();
    }

    return res.status(403).json({
        success: false,
        message: 'Forbidden - Cannot manage inventory'
    });
};

/**
 * Middleware to check if user can manage shipping
 */
const canManageShipping = (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({
            success: false,
            message: 'Unauthorized'
        });
    }

    const allowedRoles = [
        ROLES.SUPERADMIN,
        ROLES.ADMIN,
        ROLES.SHIPPING_MANAGER,
        ROLES.RECEIVING_MANAGER,
        ROLES.TRANSIT_MANAGER
    ];

    if (allowedRoles.includes(req.user.role)) {
        return next();
    }

    return res.status(403).json({
        success: false,
        message: 'Forbidden - Cannot manage shipping'
    });
};

/**
 * Middleware to check if user can create purchase orders
 */
const canCreatePO = (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({
            success: false,
            message: 'Unauthorized'
        });
    }

    const allowedRoles = [
        ROLES.SUPERADMIN,
        ROLES.ADMIN,
        ROLES.INVENTORY_MANAGER
    ];

    if (allowedRoles.includes(req.user.role)) {
        return next();
    }

    return res.status(403).json({
        success: false,
        message: 'Forbidden - Cannot create purchase orders'
    });
};

/**
 * Middleware to log access attempts (for audit)
 */
const logAccess = (req, res, next) => {
    if (req.user) {
        console.log(`[ACCESS] ${new Date().toISOString()} - User: ${req.user.userId}, Role: ${req.user.role}, Org: ${req.user.orgName}, Path: ${req.path}, Method: ${req.method}`);
    }
    next();
};

/**
 * Middleware to require SuperAdmin role
 * Usage: router.get('/path', authenticate, requireSuperAdmin, handler)
 */
const requireSuperAdmin = (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({
            success: false,
            message: 'Unauthorized - No user found'
        });
    }

    if (req.user.role !== ROLES.SUPERADMIN) {
        return res.status(403).json({
            success: false,
            message: 'Forbidden - SuperAdmin access required',
            userRole: req.user.role
        });
    }

    next();
};

/**
 * Middleware to require organization admin role (not SuperAdmin)
 * Usage: router.get('/path', authenticate, requireOrgAdmin, handler)
 */
const requireOrgAdmin = (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({
            success: false,
            message: 'Unauthorized - No user found'
        });
    }

    if (req.user.role !== ROLES.ADMIN) {
        return res.status(403).json({
            success: false,
            message: 'Forbidden - Organization admin access required',
            userRole: req.user.role
        });
    }

    next();
};

/**
 * Middleware to require blockchain access (blocks SuperAdmin)
 * Usage: router.post('/path', authenticate, requireBlockchainAccess, handler)
 */
const requireBlockchainAccess = (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({
            success: false,
            message: 'Unauthorized - No user found'
        });
    }

    if (!canAccessBlockchain(req.user.role)) {
        return res.status(403).json({
            success: false,
            message: 'Forbidden - Blockchain access not allowed for this role. SuperAdmin uses MongoDB operations only.',
            userRole: req.user.role
        });
    }

    next();
};

module.exports = {
    authorize,
    checkPermission,
    checkOrganization,
    canManageInventory,
    canManageShipping,
    canCreatePO,
    logAccess,
    requireSuperAdmin,
    requireOrgAdmin,
    requireBlockchainAccess
};
