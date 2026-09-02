const { normalizeOrgType } = require('../config/networkTopology');

// User Roles (matching v1 implementation)
const ROLES = {
    SUPERADMIN: 'superadmin',
    ADMIN: 'admin',
    INVENTORY_CONTROLLER: 'Inventory Controller',
    INVENTORY_MANAGER: 'Inventory Manager',
    SHIPPING_MANAGER: 'Shipping Manager',
    RECEIVING_MANAGER: 'Receiving Manager',
    TRANSIT_MANAGER: 'Transit Manager',
    USER: 'User'
};

// Role Permissions
const PERMISSIONS = {
    [ROLES.SUPERADMIN]: [
        'manage_all_organizations',
        'manage_all_admins',
        'view_all_data',
        'system_configuration',
        'manage_role_types',
        'manage_org_types'
        // NOTE: SuperAdmin does NOT have blockchain permissions
        // SuperAdmin uses MongoDB operations only
    ],
    [ROLES.ADMIN]: [
        'manage_org_users',
        'view_org_data',
        'create_po',
        'manage_inventory',
        'manage_shipping',
        'org_settings',
        'org_track_trace',
        // Blockchain permissions for organization admins
        'blockchain_access',
        'submit_transactions',
        'query_ledger'
    ],
    [ROLES.INVENTORY_CONTROLLER]: [
        'manage_catalog',
        'view_inventory',
        'create_products',
        'edit_products',
        'delete_products',
        'manage_categories',
        'view_track_trace'
    ],
    [ROLES.INVENTORY_MANAGER]: [
        'create_po',
        'approve_po',
        'reject_po',
        'view_inventory',
        'manage_stock',
        'manage_orders',
        'view_track_trace',
        'api_connector'  // For manufacturers
    ],
    [ROLES.SHIPPING_MANAGER]: [
        'create_shipping_bill',
        'update_shipment',
        'track_shipment',
        'manage_logistics',
        'pallet_configuration',
        'package_details',
        'view_track_trace'
    ],
    [ROLES.RECEIVING_MANAGER]: [
        'view_shipping_bills',
        'receive_shipment',
        'update_receiving_status',
        'view_track_trace'
    ],
    [ROLES.TRANSIT_MANAGER]: [
        'view_shipping_bills',
        'update_transit_status',
        'manage_logistics',
        'view_track_trace'
    ],
    [ROLES.USER]: [
        'view_own_data',
        'create_basic_records'
    ]
};

// Organizations (excluding SuperAdmin - it's a role, not an organization)
const ORGANIZATIONS = {
    MANUFACTURER: 'Manufacturer',
    DISTRIBUTOR: 'Distributor',
    WHOLESALER1: 'Wholesaler1',
    WHOLESALER2: 'Wholesaler2',
    RETAILER1: 'Retailer1',
    RETAILER2: 'Retailer2',
    RETAILER3: 'Retailer3',
    LOGISTICS1: 'Logistics1',
    LOGISTICS2: 'Logistics2'
};

// Organization Types (excluding SuperAdmin - it's a role, not an org type)
const ORG_TYPES = {
    MANUFACTURER: 'manufacturer',
    DISTRIBUTOR: 'distributor',
    WHOLESALER: 'wholesaler',
    RETAILER: 'retailer',
    LOGISTICS: 'logistics'
};

// Helper functions
const hasPermission = (role, permission) => {
    return PERMISSIONS[role]?.includes(permission) || false;
};

const isSuperAdmin = (role) => {
    return role === ROLES.SUPERADMIN;
};

const isAdmin = (role) => {
    // Only organization admins, NOT SuperAdmin
    return role === ROLES.ADMIN;
};

const canAccessBlockchain = (role) => {
    // SuperAdmin cannot access blockchain
    if (role === ROLES.SUPERADMIN) {
        return false;
    }
    // All other roles can access blockchain
    return true;
};

const canManageInventory = (role) => {
    return [
        ROLES.SUPERADMIN,
        ROLES.ADMIN,
        ROLES.INVENTORY_CONTROLLER,
        ROLES.INVENTORY_MANAGER
    ].includes(role);
};

const canManageShipping = (role) => {
    return [
        ROLES.SUPERADMIN,
        ROLES.ADMIN,
        ROLES.SHIPPING_MANAGER,
        ROLES.RECEIVING_MANAGER,
        ROLES.TRANSIT_MANAGER
    ].includes(role);
};

const canViewTrackTrace = (role) => {
    // All roles can view track & trace
    return true;
};

// Get navigation items based on role and organization type
const getNavigationForRole = (role, orgType) => {
    // Strip trailing digits so "wholesaler1", "wholesaler2", etc. all match "wholesaler"
    orgType = normalizeOrgType(orgType);
    // SuperAdmin - System-wide management
    if (role === ROLES.SUPERADMIN) {
        return [
            { name: 'Dashboard', link: '/superadmin/dashboard', icon: 'home' },
            { name: 'Organizations', link: '/superadmin/organizations', icon: 'building' },
            { name: 'Admins', link: '/superadmin/admins', icon: 'users' },
            { name: 'Track & Trace', link: '/batches/view', icon: 'map' },
            { name: 'Role Types', link: '/superadmin/roles', icon: 'shield' },
            { name: 'Organization Types', link: '/superadmin/org-types', icon: 'sitemap' },
            { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
        ];
    }
    
    // Admin role - organization-specific menus
    if (role === ROLES.ADMIN) {
        switch(orgType) {
            case ORG_TYPES.MANUFACTURER:
                return [
                    { name: 'Dashboard', link: '/dashboard', icon: 'home' },
                    { name: 'Products', link: '/inventory/catalog', icon: 'box',
                      submenu: [
                        { name: 'Product Catalog', link: '/inventory/catalog' },
                        { name: 'Create Product', link: '/inventory/products/create' }
                      ]
                    },
                    { name: 'Purchase Orders (Incoming)', link: '/po/view', icon: 'file-invoice',
                      submenu: [
                        { name: 'Incoming Orders', link: '/po/view' },
                        { name: 'Accept/Reject', link: '/po/view' }
                      ]
                    },
                    { name: 'Batches', link: '/batches/view', icon: 'cubes',
                      submenu: [
                        { name: 'Create Batches', link: '/batches/create' },
                        { name: 'View Batches', link: '/batches/view' }
                      ]
                    },
                    { name: 'Shipping', link: '/shipping/view', icon: 'truck',
                      submenu: [
                        { name: 'Create Shipping Bill', link: '/shipping/create' },
                        { name: 'View Shipments', link: '/shipping/view' }
                      ]
                    },
                    { name: 'Inventory', link: '/inventory/dashboard', icon: 'warehouse' },
                    { name: 'Track & Trace', link: '/batches/view', icon: 'map' },
                    { name: 'Users', link: '/users', icon: 'users' },
                    { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
                ];
            
            case ORG_TYPES.DISTRIBUTOR:
                return [
                    { name: 'Dashboard', link: '/dashboard', icon: 'home' },
                    { name: 'Purchase Orders (Buy)', link: '/po/view', icon: 'shopping-cart',
                      submenu: [
                        { name: 'Create PO', link: '/po/create' },
                        { name: 'View Orders', link: '/po/view' }
                      ]
                    },
                    { name: 'Orders (Sell)', link: '/po/view', icon: 'file-invoice',
                      submenu: [
                        { name: 'Incoming Orders', link: '/po/view' },
                        { name: 'Accept/Reject', link: '/po/view' }
                      ]
                    },
                    { name: 'Receiving', link: '/receiving/create-grn', icon: 'inbox',
                      submenu: [
                        { name: 'View Shipments', link: '/shipping/view' },
                        { name: 'Create GRN', link: '/receiving/create-grn' }
                      ]
                    },
                    { name: 'Shipping', link: '/shipping/view', icon: 'truck',
                      submenu: [
                        { name: 'Create Shipping Bill', link: '/shipping/create' },
                        { name: 'View Shipments', link: '/shipping/view' }
                      ]
                    },
                    { name: 'Inventory', link: '/inventory/dashboard', icon: 'warehouse' },
                    { name: 'Batches', link: '/batches/view', icon: 'cubes',
                      submenu: [
                        { name: 'View Batches', link: '/batches/view' },
                        { name: 'Track Product', link: '/batches/track' }
                      ]
                    },
                    { name: 'Track & Trace', link: '/batches/view', icon: 'map' },
                    { name: 'Users', link: '/users', icon: 'users' },
                    { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
                ];

            case ORG_TYPES.WHOLESALER:
                return [
                    { name: 'Dashboard', link: '/dashboard', icon: 'home' },
                    { name: 'Purchase Orders (Buy)', link: '/po/view', icon: 'shopping-cart',
                      submenu: [
                        { name: 'Create PO', link: '/po/create' },
                        { name: 'View Orders', link: '/po/view' }
                      ]
                    },
                    { name: 'Orders (Sell)', link: '/po/view', icon: 'file-invoice',
                      submenu: [
                        { name: 'Incoming Orders', link: '/po/view' },
                        { name: 'Accept/Reject', link: '/po/view' }
                      ]
                    },
                    { name: 'Receiving', link: '/receiving/create-grn', icon: 'inbox',
                      submenu: [
                        { name: 'View Shipments', link: '/shipping/view' },
                        { name: 'Create GRN', link: '/receiving/create-grn' }
                      ]
                    },
                    { name: 'Shipping', link: '/shipping/view', icon: 'truck',
                      submenu: [
                        { name: 'Create Shipping Bill', link: '/shipping/create' },
                        { name: 'View Shipments', link: '/shipping/view' }
                      ]
                    },
                    { name: 'Inventory', link: '/inventory/dashboard', icon: 'warehouse' },
                    { name: 'Batches', link: '/batches/view', icon: 'cubes',
                      submenu: [
                        { name: 'View Batches', link: '/batches/view' },
                        { name: 'Track Product', link: '/batches/track' }
                      ]
                    },
                    { name: 'Track & Trace', link: '/batches/view', icon: 'map' },
                    { name: 'Users', link: '/users', icon: 'users' },
                    { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
                ];

            case ORG_TYPES.RETAILER:
                return [
                    { name: 'Dashboard', link: '/dashboard', icon: 'home' },
                    { name: 'Purchase Orders', link: '/po/view', icon: 'shopping-cart',
                      submenu: [
                        { name: 'Create PO', link: '/po/create' },
                        { name: 'View Orders', link: '/po/view' }
                      ]
                    },
                    { name: 'Receiving', link: '/receiving/create-grn', icon: 'inbox',
                      submenu: [
                        { name: 'View Shipments', link: '/shipping/view' },
                        { name: 'Create GRN', link: '/receiving/create-grn' }
                      ]
                    },
                    { name: 'Inventory', link: '/inventory/dashboard', icon: 'warehouse' },
                    { name: 'Batches', link: '/batches/view', icon: 'cubes',
                      submenu: [
                        { name: 'View Batches', link: '/batches/view' },
                        { name: 'Track Product', link: '/batches/track' }
                      ]
                    },
                    { name: 'Track & Trace', link: '/batches/view', icon: 'map' },
                    { name: 'Users', link: '/users', icon: 'users' },
                    { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
                ];
            
            case ORG_TYPES.LOGISTICS:
                return [
                    { name: 'Dashboard', link: '/dashboard', icon: 'home' },
                    { name: 'Shipments', link: '/shipping/view', icon: 'truck',
                      submenu: [
                        { name: 'View Shipments', link: '/shipping/view' },
                        { name: 'Update Status', link: '/shipping/view' }
                      ]
                    },
                    { name: 'Drivers', link: '/driver', icon: 'users',
                      submenu: [
                        { name: 'View Drivers', link: '/driver' },
                        { name: 'Add Driver', link: '/driver/create' }
                      ]
                    },
                    { name: 'Vehicles', link: '/vehicle', icon: 'truck',
                      submenu: [
                        { name: 'View Vehicles', link: '/vehicle' },
                        { name: 'Add Vehicle', link: '/vehicle/create' }
                      ]
                    },
                    { name: 'IoT Tracking', link: '/iot/gps', icon: 'satellite',
                      submenu: [
                        { name: 'GPS Tracking', link: '/iot/gps' },
                        { name: 'Temperature', link: '/iot/temperature' },
                        { name: 'Alerts', link: '/iot/alerts' }
                      ]
                    },
                    { name: 'Track & Trace', link: '/batches/view', icon: 'map' },
                    { name: 'Users', link: '/users', icon: 'users' },
                    { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
                ];
            
            default:
                return [
                    { name: 'Dashboard', link: '/dashboard', icon: 'home' },
                    { name: 'Track & Trace', link: '/batches/view', icon: 'map' },
                    { name: 'Users', link: '/users', icon: 'users' },
                    { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
                ];
        }
    }
    
    // Inventory Controller
    if (role === ROLES.INVENTORY_CONTROLLER) {
        return [
            { name: 'Dashboard', link: '/dashboard', icon: 'home' },
            { name: 'Inventory', link: '/inventory/dashboard', icon: 'warehouse' },
            { name: 'Products Catalogue', link: '/inventory/catalog', icon: 'box',
              submenu: [
                { name: 'View Catalog', link: '/inventory/catalog' },
                { name: 'Create Product', link: '/inventory/products/create' }
              ]
            },
            { name: 'Track & Trace', link: '/batches/view', icon: 'map' },
            { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
        ];
    }
    
    // Inventory Manager
    if (role === ROLES.INVENTORY_MANAGER) {
        if (orgType === ORG_TYPES.MANUFACTURER) {
            return [
                { name: 'Dashboard', link: '/dashboard', icon: 'home' },
                { name: 'Tasks', link: '/po/view', icon: 'tasks',
                  submenu: [
                    { name: 'View Orders', link: '/po/view' },
                    { name: 'Accept/Reject', link: '/po/view' }
                  ]
                },
                { name: 'Batches', link: '/batches/view', icon: 'cubes',
                  submenu: [
                    { name: 'Create Batches', link: '/batches/create' },
                    { name: 'View Batches', link: '/batches/view' }
                  ]
                },
                { name: 'Track & Trace', link: '/batches/view', icon: 'map' },
                { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
            ];
        } else {
            return [
                { name: 'Dashboard', link: '/dashboard', icon: 'home' },
                { name: 'Tasks', link: '/po/view', icon: 'tasks' },
                { name: 'Track & Trace', link: '/batches/view', icon: 'map' },
                { name: 'Inventory', link: '/inventory/dashboard', icon: 'warehouse' },
                { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
            ];
        }
    }
    
    // Shipping Manager
    if (role === ROLES.SHIPPING_MANAGER) {
        const isLogistics = orgType === ORG_TYPES.LOGISTICS;
        return [
            { name: 'Dashboard', link: '/dashboard', icon: 'home' },
            { name: 'Shipping', link: '/shipping/view', icon: 'truck',
              submenu: [
                { name: 'Create Shipping Bill', link: '/shipping/create' },
                { name: 'View Shipments', link: '/shipping/view' }
              ]
            },
            ...(isLogistics ? [
                { name: 'Drivers', link: '/driver', icon: 'users',
                  submenu: [
                    { name: 'View Drivers', link: '/driver' },
                    { name: 'Add Driver', link: '/driver/create' }
                  ]
                },
                { name: 'Vehicles', link: '/vehicle', icon: 'truck',
                  submenu: [
                    { name: 'View Vehicles', link: '/vehicle' },
                    { name: 'Add Vehicle', link: '/vehicle/create' }
                  ]
                },
            ] : []),
            { name: 'Track & Trace', link: '/batches/view', icon: 'map' },
            { name: 'Pallet Configuration', link: '/shipping/pallets', icon: 'pallet' },
            { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
        ];
    }
    
    // Receiving Manager
    if (role === ROLES.RECEIVING_MANAGER) {
        return [
            { name: 'Dashboard', link: '/dashboard', icon: 'home' },
            { name: 'Task', link: '/shipping/view', icon: 'clipboard-check' },
            { name: 'Receiving', link: '/receiving/create-grn', icon: 'inbox',
              submenu: [
                { name: 'View Shipments', link: '/shipping/view' },
                { name: 'Confirm Receipt (GRN)', link: '/receiving/create-grn' }
              ]
            },
            { name: 'Track & Trace', link: '/batches/view', icon: 'map' },
            { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
        ];
    }
    
    // Transit Manager
    if (role === ROLES.TRANSIT_MANAGER) {
        const isLogistics = orgType === ORG_TYPES.LOGISTICS;
        return [
            { name: 'Dashboard', link: '/dashboard', icon: 'home' },
            { name: 'Shipments', link: '/shipping/view', icon: 'truck',
              submenu: [
                { name: 'View Shipments', link: '/shipping/view' },
                { name: 'Update Status', link: '/shipping/view' }
              ]
            },
            ...(isLogistics ? [
                { name: 'Drivers', link: '/driver', icon: 'users',
                  submenu: [
                    { name: 'View Drivers', link: '/driver' },
                    { name: 'Add Driver', link: '/driver/create' }
                  ]
                },
                { name: 'Vehicles', link: '/vehicle', icon: 'truck',
                  submenu: [
                    { name: 'View Vehicles', link: '/vehicle' },
                    { name: 'Add Vehicle', link: '/vehicle/create' }
                  ]
                },
            ] : []),
            { name: 'Track & Trace', link: '/batches/view', icon: 'map' },
            { name: 'IoT Tracking', link: '/iot/gps', icon: 'satellite',
              submenu: [
                { name: 'GPS Tracking', link: '/iot/gps' },
                { name: 'Temperature', link: '/iot/temperature' },
                { name: 'Alerts', link: '/iot/alerts' }
              ]
            },
            { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
        ];
    }

    // Default for other roles
    return [
        { name: 'Dashboard', link: '/dashboard', icon: 'home' },
        { name: 'Profile Settings', link: '/profile', icon: 'user-cog' }
    ];
};

// Get default route based on role
const getDefaultRoute = (role, orgType) => {
    switch(role) {
        case ROLES.SUPERADMIN:
            return '/superadmin/dashboard';
        case ROLES.ADMIN:
            return '/dashboard';
        case ROLES.INVENTORY_CONTROLLER:
            return '/inventory/catalog';
        case ROLES.INVENTORY_MANAGER:
            return '/po/view';
        case ROLES.SHIPPING_MANAGER:
            return '/shipping/packages';
        case ROLES.RECEIVING_MANAGER:
            return '/shipping/view';
        case ROLES.TRANSIT_MANAGER:
            return '/shipping/view';
        default:
            return '/dashboard';
    }
};

module.exports = {
    ROLES,
    PERMISSIONS,
    ORGANIZATIONS,
    ORG_TYPES,
    hasPermission,
    isSuperAdmin,
    isAdmin,
    canAccessBlockchain,
    canManageInventory,
    canManageShipping,
    canViewTrackTrace,
    getNavigationForRole,
    getDefaultRoute
};
