const mongoose = require('mongoose');

const adminSchema = new mongoose.Schema({
    _id: mongoose.Schema.Types.ObjectId,
    adminname: {
        type: String,
        required: true
    },
    email: {
        type: String,
        required: true,
        unique: true,
        lowercase: true,
        match: /[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?/
    },
    password: {
        type: String,
        required: true
    },
    phonenumber: {
        type: Number,
        required: true
    },
    org: {
        type: String,
        required: true
        // "superadmin" for SuperAdmin, "manufacturer" for org admin, etc.
    },
    orgtype: {
        type: String,
        required: true
        // "superadmin" for SuperAdmin, "Manufacturer" for org admin, etc.
    },
    status: {
        type: String,
        default: 'Active'
    },
    enrolledBy: {
        type: String,
        required: true
    },
    createdAt: {
        type: Date,
        default: Date.now
    },
    updatedAt: {
        type: Date,
        default: Date.now
    }
});

// Update timestamp on save
adminSchema.pre('save', function(next) {
    this.updatedAt = Date.now();
    next();
});

module.exports = mongoose.model('Admin', adminSchema);
