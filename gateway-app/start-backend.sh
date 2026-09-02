#!/bin/bash

# Start backend with TLS verification disabled for development
# This allows self-signed certificates to work with gRPC

echo "Starting trustflow Backend..."
echo "Note: TLS certificate verification is disabled for development"
echo ""

# Disable Node.js TLS verification (affects gRPC)
export NODE_TLS_REJECT_UNAUTHORIZED=0

# Enable gRPC debug logging (comment out for production)
# export GRPC_VERBOSITY=DEBUG
# export GRPC_TRACE=all

# Start the backend
npm start
