const mongoose = require('mongoose');

const orgSchema = new mongoose.Schema({
    _id: mongoose.Schema.Types.ObjectId,
    orgname: {
        type: String,
        required: true
    },
    orgtype: {
        type: String,
        required: true
    },
    gln: {
        type: String,
        sparse: true
    },
    address: {
        type: String
    },
    contactPerson: {
        type: String
    },
    email: {
        type: String,
        lowercase: true
    },
    phone: {
        type: String
    },
    status: {
        type: String,
        default: 'Active'
    },
    orgPic: {
        data: Buffer,
        contentType: String
    },
    createdBy: {
        type: String
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
orgSchema.pre('save', function(next) {
    this.updatedAt = Date.now();
    next();
});

module.exports = mongoose.model('Org', orgSchema);
