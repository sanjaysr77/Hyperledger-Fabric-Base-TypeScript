/**
 * Simple Fabric Network Gateway Application Server
 * Hyperledger Fabric 2.5.x with Gateway API
 */

// CRITICAL: Set this BEFORE requiring any modules
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const express = require('express');
const bodyParser = require('body-parser');
const cookieParser = require('cookie-parser');
const morgan = require('morgan');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const mongoose = require('mongoose');
require('dotenv').config();

// Routes
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/user');
const assetRoutes = require('./routes/asset');

// MongoDB Connection
const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/fabricnetwork';

console.log('Attempting to connect to MongoDB...');
const { startEventListener } = require('./utils/iotEventListener');

mongoose.connect(mongoUri)
    .then(() => {
        console.log('✅ Successfully connected to MongoDB');
        startEventListener('buyer', 'Admin', 'mychannel').catch(() => {});
    })
    .catch(err => {
        console.error('❌ Error connecting to MongoDB:', err.message);
        console.error('\n⚠️  Server will continue running but database features will not work.\n');
    });

const port = process.env.PORT || 3000;

// Express App
const app = express();

// Middleware
app.use(cookieParser());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }));
app.use(morgan('dev'));
app.use(cors());
app.use(compression());
app.use(helmet());

app.disable('x-powered-by');

// Security Headers
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Headers', 'Origin,X-Requested-With,Content-Type,Accept,Authorization');
    res.header('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.header('Pragma', 'no-cache');
    res.header('Expires', '0');
    res.header('Content-Security-Policy', "script-src 'self'");

    if (req.method === 'OPTIONS') {
        res.header('Access-Control-Allow-Methods', 'PUT,POST,GET,PATCH,DELETE');
        return res.status(200).json({});
    }

    if (req.path.match(/\./) || req.path.match(/\/Old*/)) {
        return res.status(500).json({ error: { message: 'Not a valid route' } });
    }

    next();
});

// Health Check
app.get('/health', (req, res) => {
    res.status(200).json({
        success: true,
        message: 'Fabric Network Gateway API is running',
        version: '1.0.0',
        fabric: '2.5.x'
    });
});

// Public routes (no auth required)
app.use('/api/auth', authRoutes);

// Import authentication middleware
const { authenticate } = require('./controllers/authController');

// API Routes with Authentication
app.use('/api/user', authenticate, userRoutes);
app.use('/api/asset', authenticate, assetRoutes);

// Error Handler
app.use((error, req, res, next) => {
    console.error('Error:', error);
    res.status(error.status || 500).json({
        error: { message: error.message || 'Internal server error' }
    });
});

// 404 Handler
app.use((req, res) => {
    res.status(404).json({ error: { message: 'Route not found' } });
});

// Start Server
app.listen(port, () => {
    console.log('='.repeat(50));
    console.log('Simple Fabric Network Gateway');
    console.log('Hyperledger Fabric 2.5.x');
    console.log('='.repeat(50));
    console.log(`Server running on port ${port}`);
    console.log(`Health check: http://localhost:${port}/health`);
    console.log('='.repeat(50));
});

module.exports = app;
