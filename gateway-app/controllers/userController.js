const User = require('../models/user');
const Admin = require('../models/admin');
const bcrypt = require('bcrypt');

// Create user
exports.createUser = async (req, res) => {
    try {
        const { name, fullname, username, email, phone, status, role, password } = req.body;

        const userName = name || fullname || username;

        if (!userName || !email) {
            return res.status(400).json({
                success: false,
                message: 'Name/username and email are required'
            });
        }

        const existing = await User.findOne({ email: String(email).toLowerCase() });
        if (existing) {
            return res.status(409).json({
                success: false,
                message: 'A user with this email already exists'
            });
        }

        const mongoose = require('mongoose');
        const hashedPassword = await bcrypt.hash(String(password || 'password123'), 10);

        const user = new User({
            _id: new mongoose.Types.ObjectId(),
            name: String(userName),
            email: String(email).toLowerCase(),
            phonenumber: parseInt(phone) || 0,
            status: String(status || 'Active'),
            role: String(role || 'user'),
            password: hashedPassword,
            org: req.user.organization,
            orgtype: req.user.orgType || req.user.organization,
            enrolledBy: req.user.userId
        });
        await user.save();

        res.status(201).json({
            success: true,
            message: 'User created successfully'
        });
    } catch (error) {
        console.error('Error creating user:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to create user',
            error: error.message
        });
    }
};

// Create admin user
exports.createAdmin = async (req, res) => {
    try {
        const { name, email, phone, status, password } = req.body;

        if (!name || !email) {
            return res.status(400).json({ success: false, message: 'Name and email are required' });
        }

        const existing = await Admin.findOne({ email: String(email).toLowerCase() });
        if (existing) {
            return res.status(409).json({ success: false, message: 'Admin with this email already exists' });
        }

        const mongoose = require('mongoose');
        const Admin = require('../models/admin');
        const hashedPassword = await bcrypt.hash(String(password || 'password123'), 10);

        const admin = new Admin({
            _id: new mongoose.Types.ObjectId(),
            adminname: String(name),
            email: String(email).toLowerCase(),
            password: hashedPassword,
            phonenumber: parseInt(phone) || 0,
            org: req.user.organization,
            orgtype: req.user.orgType || req.user.organization,
            status: String(status || 'Active'),
            enrolledBy: req.user.userId
        });
        await admin.save();

        res.status(201).json({ success: true, message: 'Admin created successfully' });
    } catch (error) {
        console.error('Error creating admin:', error);
        res.status(500).json({ success: false, message: 'Failed to create admin', error: error.message });
    }
};

// Create organization
exports.createOrganization = async (req, res) => {
    try {
        const { name, type, gln, address, email, phone } = req.body;

        if (!name || !type) {
            return res.status(400).json({ success: false, message: 'Name and type are required' });
        }

        const mongoose = require('mongoose');
        const Org = require('../models/org');

        const org = new Org({
            _id: new mongoose.Types.ObjectId(),
            orgname: String(name),
            orgtype: String(type),
            gln: gln ? String(gln) : undefined,
            address: address ? String(address) : undefined,
            email: email ? String(email).toLowerCase() : undefined,
            phone: phone ? String(phone) : undefined,
            status: 'Active',
            createdBy: req.user.userId
        });
        await org.save();

        res.status(201).json({ success: true, message: 'Organization created successfully' });
    } catch (error) {
        console.error('Error creating organization:', error);
        res.status(500).json({ success: false, message: 'Failed to create organization', error: error.message });
    }
};

// Read user
exports.getUser = async (req, res) => {
    try {
        const { username } = req.params;

        const user = await User.findOne({ name: username, org: req.user.organization }).select('-password');
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        res.json({ success: true, data: user });
    } catch (error) {
        console.error('Error reading user:', error);
        res.status(500).json({ success: false, message: 'Failed to read user', error: error.message });
    }
};

// Read all users
exports.getAllUsers = async (req, res) => {
    try {
        // Use MongoDB User model instead of blockchain to avoid private collection issues
        // This is more efficient and avoids the private data collection error
        const users = await User.find({ org: req.user.organization })
            .select('-password')
            .sort({ createdAt: -1 });

        res.json({
            success: true,
            count: users.length,
            data: users
        });
    } catch (error) {
        console.error('Error reading users:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to read users',
            error: error.message
        });
    }
};

// Delete user
exports.deleteUser = async (req, res) => {
    try {
        const { username } = req.params;

        const user = await User.findOneAndDelete({ name: username, org: req.user.organization });
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        res.json({ success: true, message: 'User deleted successfully' });
    } catch (error) {
        console.error('Error deleting user:', error);
        res.status(500).json({ success: false, message: 'Failed to delete user', error: error.message });
    }
};

// Update user
exports.updateUser = async (req, res) => {
    try {
        const { username } = req.params;
        const { email, phone, status, role } = req.body;

        const user = await User.findOneAndUpdate(
            { name: username, org: req.user.organization },
            { $set: { ...(email && { email }), ...(phone && { phonenumber: parseInt(phone) }), ...(status && { status }), ...(role && { role }), updatedAt: Date.now() } },
            { new: true }
        ).select('-password');

        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        res.json({ success: true, message: 'User updated successfully', data: user });
    } catch (error) {
        console.error('Error updating user:', error);
        res.status(500).json({ success: false, message: 'Failed to update user', error: error.message });
    }
};

// Get users count for current org
exports.getUsersCount = async (req, res) => {
    try {
        const orgName = req.user.organization;
        const count = await User.countDocuments({ org: orgName });
        res.json({ success: true, count });
    } catch (error) {
        console.error('Error getting users count:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to get users count',
            error: error.message
        });
    }
};

// Get users by org (admin/superadmin use)
exports.getUsersByOrg = async (req, res) => {
    try {
        const { orgId } = req.params;
        const users = await User.find({ org: orgId })
            .select('-password')
            .sort({ createdAt: -1 });
        res.json({ success: true, count: users.length, data: users });
    } catch (error) {
        console.error('Error getting users by org:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to get users by org',
            error: error.message
        });
    }
};

// Update user profile picture
exports.updateProfilePic = async (req, res) => {
    try {
        const { username } = req.params;
        const { imageData, contentType } = req.body;

        if (!imageData) {
            return res.status(400).json({ success: false, message: 'imageData is required' });
        }

        const user = await User.findOneAndUpdate(
            { name: username, org: req.user.organization },
            {
                $set: {
                    profilePic: {
                        data: Buffer.from(imageData, 'base64'),
                        contentType: contentType || 'image/jpeg'
                    },
                    updatedAt: Date.now()
                }
            },
            { new: true }
        ).select('-password');

        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        res.json({ success: true, message: 'Profile picture updated successfully' });
    } catch (error) {
        console.error('Error updating profile picture:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update profile picture',
            error: error.message
        });
    }
};
