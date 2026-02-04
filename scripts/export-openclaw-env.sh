#!/bin/bash
# File: scripts/export-openclaw-env.sh
# Purpose: Export all required environment variables from Doppler for OpenClaw

set -e

echo "Exporting OpenClaw environment variables from Doppler..."

# Export all secrets from Doppler (backend/dev) to .env file
cd /opt/openclaw
doppler secrets download --project backend --config dev --format env --no-file --silent 2>&1 > .env

# Add OpenClaw-specific variables that aren't in Doppler
echo "" >> .env
echo "# OpenClaw-specific paths" >> .env
echo "OPENCLAW_CONFIG_DIR=/root/.openclaw" >> .env
echo "OPENCLAW_WORKSPACE_DIR=/root/.openclaw/workspace" >> .env
echo "DOPPLER_PROJECT=backend" >> .env
echo "DOPPLER_ENVIRONMENT=dev" >> .env
echo "DOPPLER_CONFIG=dev" >> .env

echo "Environment variables written to /opt/openclaw/.env"
echo "Total lines in .env: $(wc -l < .env)"
