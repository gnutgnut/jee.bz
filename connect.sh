#!/bin/bash
# SSH connection helper for Proxmox server
# Usage: ./connect.sh [command]
# If no command provided, opens interactive shell

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load config from connect.conf (copy connect.conf.example to get started)
if [ -f "${SCRIPT_DIR}/connect.conf" ]; then
    source "${SCRIPT_DIR}/connect.conf"
else
    echo "Error: connect.conf not found. Copy connect.conf.example to connect.conf and configure it."
    exit 1
fi

# Use SSH key if it exists, otherwise use password auth
if [ -f "${SSH_KEY}" ]; then
    SSH_OPTS="-i ${SSH_KEY}"
else
    SSH_OPTS=""
fi

if [ $# -eq 0 ]; then
    echo "Connecting to Proxmox server..."
    ssh -p ${PROXMOX_PORT} ${SSH_OPTS} ${PROXMOX_USER}@${PROXMOX_HOST}
else
    ssh -p ${PROXMOX_PORT} ${SSH_OPTS} ${PROXMOX_USER}@${PROXMOX_HOST} "$@"
fi
