#!/bin/bash
# k6 Load Testing Setup Script
# This script installs k6 and dependencies for load testing

set -e

echo "🔧 Installing k6 load testing tool..."

# Check if k6 is already installed
if command -v k6 &> /dev/null; then
    echo "✅ k6 is already installed ($(k6 version))"
    exit 0
fi

# Detect OS and install k6
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "📦 Installing k6 on Linux..."
    sudo gpg -k
    sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
    echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
    sudo apt-get update
    sudo apt-get install k6
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "📦 Installing k6 on macOS..."
    brew install k6
else
    echo "❌ Unsupported OS: $OSTYPE"
    echo "Please install k6 manually: https://k6.io/docs/getting-started/installation/"
    exit 1
fi

echo "✅ k6 installation complete!"
k6 version
