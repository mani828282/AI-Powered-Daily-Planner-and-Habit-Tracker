#!/usr/bin/env bash
# Build script for Render deployment
set -o errexit  # Exit on error

echo "=== Installing dependencies ==="
pip install --upgrade pip
pip install -r requirements.txt

echo "=== Creating upload directories ==="
mkdir -p uploads/profile_pictures

echo "=== Build complete ==="
