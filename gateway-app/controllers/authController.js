const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const { submitTransaction, evaluateTransaction } = require('../utils/gateway');
const { ROLES, getDefaultRoute, ORG_TYPES } = require('../constants/roles');
const Admin = require('../models/admin');
const User = require('../models/user');
const Org = require('../models/org');

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const JWT_EXPIRY = process.env.JWT_EXPIRY || '24h';

// Get organization type from organization name
const getOrgType = (orgName) => {
    const orgLower = orgName.toLowerCase();
    if (orgLower.includes('buyer')) return 'buyer';
    if (orgLower.includes('seller')) return 'seller';
    return 'unknown';
};

// Login
exports.login = async (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({
                success: false,
                message: 'Email and password are required'
            });
        }

        // Step 1: Check Admin collection first (for SuperAdmin and organization admins)
        const admin = await Admin.findOne({ email: username.toLowerCase() });

        if (admin) {
            // Verify admin password
            const isPasswordValid = await bcrypt.compare(password, admin.password);
            if (!isPasswordValid) {
                return res.status(401).json({
                    success: false,
                    message: 'Invalid credentials'
                });
            }

            // Check if admin is active
            if (admin.status.toLowerCase() !== 'active') {
                return res.status(403).json({
                    success: false,
                    message: 'Admin account is not active'
                });
            }

            // Determine role based on org field
            let role;
            if (admin.org === 'superadmin') {
                role = ROLES.SUPERADMIN;  // SuperAdmin role
            } else {
                role = ROLES.ADMIN;  // Organization admin role
            }

            // Get organization details (if not superadmin)
            let orgDetails = null;
            let gln = 'superadmin';
            if (role !== ROLES.SUPERADMIN) {
                orgDetails = await Org.findOne({ orgtype: admin.orgtype });
                if (orgDetails) {
                    gln = orgDetails.gln;
                }
            }

            // Determine organization type
            const orgType = admin.orgtype === 'superadmin' ? ORG_TYPES.SUPERADMIN : getOrgType(admin.org);

            // Generate JWT token
            const token = jwt.sign(
                {
                    username: admin.adminname,
                    email: admin.email,
                    role: role,
                    organization: admin.org,
                    orgType: orgType
                },
                JWT_SECRET,
                { expiresIn: JWT_EXPIRY }
            );

            // Get default route based on role
            const redirectPath = getDefaultRoute(role, orgType);

            return res.json({
                success: true,
                message: 'Login successful',
                token,
                user: {
                    username: admin.adminname,
                    email: admin.email,
                    phone: admin.phonenumber,
                    role: role,
                    organization: admin.org,
                    orgType: orgType,
                    gln: gln,
                    status: admin.status
                },
                redirectPath
            });
        }

        // Step 2: Check User collection (for regular users)
        const user = await User.findOne({ email: username.toLowerCase() });

        if (user) {
            // Verify user password
            const isPasswordValid = await bcrypt.compare(password, user.password);
            if (!isPasswordValid) {
                return res.status(401).json({
                    success: false,
                    message: 'Invalid credentials'
                });
            }

            // Check if user is active
            if (user.status.toLowerCase() !== 'active') {
                return res.status(403).json({
                    success: false,
                    message: 'User account is not active'
                });
            }

            // Get organization details
            const orgDetails = await Org.findOne({ orgtype: user.orgtype });
            const gln = orgDetails ? orgDetails.gln : '';

            // Determine organization type
            const orgType = getOrgType(user.org);

            // Generate JWT token
            const token = jwt.sign(
                {
                    username: user.name,
                    email: user.email,
                    role: user.role,
                    organization: user.org,
                    orgType: orgType
                },
                JWT_SECRET,
                { expiresIn: JWT_EXPIRY }
            );

            // Get default route based on role
            const redirectPath = getDefaultRoute(user.role, orgType);

            return res.json({
                success: true,
                message: 'Login successful',
                token,
                user: {
                    username: user.name,
                    email: user.email,
                    phone: user.phonenumber,
                    role: user.role,
                    organization: user.org,
                    orgType: orgType,
                    gln: gln,
                    status: user.status
                },
                redirectPath
            });
        }

        // No user found in either collection
        return res.status(401).json({
            success: false,
            message: 'Invalid credentials'
        });

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({
            success: false,
            message: 'Login failed',
            error: error.message
        });
    }
};

// Register new user
exports.register = async (req, res) => {
    try {
        const { name, email, phone, password, role, organization } = req.body;

        if (!name || !email || !password || !role || !organization) {
            return res.status(400).json({
                success: false,
                message: 'All fields are required'
            });
        }

        // Check if user already exists
        const existing = await Admin.findOne({ email: email.toLowerCase() })
            || await User.findOne({ email: email.toLowerCase() });
        if (existing) {
            return res.status(409).json({
                success: false,
                message: 'A user with this email already exists'
            });
        }

        const mongoose = require('mongoose');
        const hashedPassword = await bcrypt.hash(password, 10);
        const orgType = getOrgType(organization);

        // Admins go into the Admin collection, regular users into User collection
        if (role === ROLES.ADMIN || role === ROLES.SUPERADMIN) {
            const admin = new Admin({
                _id: new mongoose.Types.ObjectId(),
                adminname: name,
                email: email.toLowerCase(),
                password: hashedPassword,
                phonenumber: parseInt(phone) || 0,
                org: organization,
                orgtype: orgType,
                status: 'Active',
                enrolledBy: 'self'
            });
            await admin.save();
        } else {
            const user = new User({
                _id: new mongoose.Types.ObjectId(),
                name,
                email: email.toLowerCase(),
                password: hashedPassword,
                phonenumber: parseInt(phone) || 0,
                status: 'Active',
                role,
                org: organization,
                orgtype: orgType,
                enrolledBy: 'self'
            });
            await user.save();
        }

        res.status(201).json({
            success: true,
            message: 'User registered successfully'
        });
    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({
            success: false,
            message: 'Registration failed',
            error: error.message
        });
    }
};

// Verify token
exports.verifyToken = (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];

        if (!token) {
            return res.status(401).json({
                success: false,
                message: 'No token provided'
            });
        }

        const decoded = jwt.verify(token, JWT_SECRET);

        res.json({
            success: true,
            user: decoded
        });
    } catch (error) {
        res.status(401).json({
            success: false,
            message: 'Invalid token'
        });
    }
};

// Middleware to authenticate requests
exports.authenticate = (req, res, next) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];

        if (!token) {
            return res.status(401).json({
                success: false,
                message: 'Authentication required'
            });
        }

        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        
        // Set properties for gateway calls
        // Use 'Admin' as the Fabric identity (not the application username)
        req.user.organization = decoded.organization;
        req.user.username = decoded.username;
        req.user.orgName = decoded.organization;
        req.user.userId = 'Admin'; // Always use Admin identity for Fabric operations
        req.user.orgType = decoded.orgType || getOrgType(decoded.organization);
        
        next();
    } catch (error) {
        res.status(401).json({
            success: false,
            message: 'Invalid or expired token'
        });
    }
};

// Middleware to check role (use RBAC middleware instead for better control)
exports.authorize = (...roles) => {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({
                success: false,
                message: 'Authentication required'
            });
        }

        if (!roles.includes(req.user.role)) {
            return res.status(403).json({
                success: false,
                message: 'Insufficient permissions',
                requiredRoles: roles,
                userRole: req.user.role
            });
        }

        next();
    };
};

// Get user navigation based on role
exports.getNavigation = (req, res) => {
    try {
        if (!req.user) {
            return res.status(401).json({
                success: false,
                message: 'Authentication required'
            });
        }

        const { getNavigationForRole } = require('../constants/roles');
        const navigation = getNavigationForRole(req.user.role, req.user.orgType);

        res.json({
            success: true,
            navigation
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Failed to get navigation',
            error: error.message
        });
    }
};
