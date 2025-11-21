#!/bin/bash
# Startup script for SQA Sinatra App
# This script checks dependencies and starts the server properly

set -e

echo "============================================================"
echo "SQA Sinatra App - Startup Script"
echo "============================================================"
echo ""

# Check if Gemfile exists
if [ ! -f "Gemfile" ]; then
  echo "Error: Gemfile not found"
  exit 1
fi

# Check if bundler is installed
if ! command -v bundle &> /dev/null; then
  echo "Error: bundler is not installed"
  echo "   Install with: gem install bundler"
  exit 1
fi

echo "Found Gemfile"

# Check if bundle is satisfied
echo ""
echo "Checking dependencies..."
if ! bundle check &> /dev/null; then
  echo "Dependencies not installed. Running bundle install..."
  bundle install
  echo "Dependencies installed"
else
  echo "All dependencies satisfied"
fi

echo ""
echo "Starting server..."
echo "============================================================"
echo "Server will be available at: http://localhost:9292"
echo "Press Ctrl+C to stop"
echo "============================================================"
echo ""

# Start the server with bundle exec
exec bundle exec rackup
