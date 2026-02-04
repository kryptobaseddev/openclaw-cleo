#!/bin/bash

echo "=== Testing Server Connections ==="

# Test OpenClaw
echo ""
echo "OpenClaw (10.0.10.20):"
source .openclaw-creds.env
if sshpass -p "$OPENCLAW_SSH_PASSWORD" ssh -o StrictHostKeyChecking=no root@10.0.10.20 "hostname" &>/dev/null; then
    echo "✅ Connection successful"
    sshpass -p "$OPENCLAW_SSH_PASSWORD" ssh -o StrictHostKeyChecking=no root@10.0.10.20 "docker ps --format '  Container: {{.Names}} ({{.Status}})'"
else
    echo "❌ Connection failed"
fi

# Test CleoBot
echo ""
echo "CleoBot (10.0.10.21):"
source .cleobot-creds.env
if sshpass -p "$CLEOBOT_SSH_PASSWORD" ssh -o StrictHostKeyChecking=no root@10.0.10.21 "hostname" &>/dev/null; then
    echo "✅ Connection successful"
    sshpass -p "$CLEOBOT_SSH_PASSWORD" ssh -o StrictHostKeyChecking=no root@10.0.10.21 "docker ps --format '  Container: {{.Names}} ({{.Status}})'"
else
    echo "❌ Connection failed"
fi

echo ""
echo "=== Test Complete ==="
