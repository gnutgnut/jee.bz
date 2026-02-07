#!/bin/bash
# SSH Key-Based Authentication Setup for Proxmox
# Run this script on your LOCAL MACHINE (Windows with Git Bash/WSL)

set -e

PROXMOX_HOST="jee.bz"
PROXMOX_USER="root"
PROXMOX_PORT="22"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
SSH_KEY_NAME="proxmox-claude-code"

echo "============================================"
echo "SSH Key-Based Authentication Setup"
echo "============================================"
echo ""
echo "Target server: ${PROXMOX_USER}@${PROXMOX_HOST}"
echo ""

# Check if SSH key already exists
if [ -f "${SSH_KEY_PATH}" ]; then
    echo "SSH key already exists at: ${SSH_KEY_PATH}"
    echo ""
    read -p "Use existing key? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Creating new key with custom name..."
        SSH_KEY_PATH="$HOME/.ssh/${SSH_KEY_NAME}"

        if [ -f "${SSH_KEY_PATH}" ]; then
            echo "Key ${SSH_KEY_PATH} already exists!"
            echo "Please remove it or choose a different name."
            exit 1
        fi

        ssh-keygen -t ed25519 -f "${SSH_KEY_PATH}" -C "${SSH_KEY_NAME}@$(hostname)"
    fi
else
    echo "No SSH key found. Generating new Ed25519 key..."
    echo ""

    # Create .ssh directory if it doesn't exist
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # Generate key
    ssh-keygen -t ed25519 -f "${SSH_KEY_PATH}" -C "${SSH_KEY_NAME}@$(hostname)"
fi

echo ""
echo "============================================"
echo "Copying Public Key to Proxmox"
echo "============================================"
echo ""
echo "You will be prompted for your Proxmox root password..."
echo ""

# Copy public key to Proxmox
if command -v ssh-copy-id &> /dev/null; then
    # Use ssh-copy-id if available (Linux/Mac/WSL/Git Bash with openssh)
    ssh-copy-id -i "${SSH_KEY_PATH}.pub" -p ${PROXMOX_PORT} ${PROXMOX_USER}@${PROXMOX_HOST}
else
    # Manual method for Windows without ssh-copy-id
    echo "ssh-copy-id not found, using manual method..."

    PUB_KEY=$(cat "${SSH_KEY_PATH}.pub")

    ssh -p ${PROXMOX_PORT} ${PROXMOX_USER}@${PROXMOX_HOST} \
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '${PUB_KEY}' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
fi

echo ""
echo "============================================"
echo "Testing Connection"
echo "============================================"
echo ""

# Test connection
echo "Testing SSH connection without password..."
if ssh -p ${PROXMOX_PORT} -i "${SSH_KEY_PATH}" -o BatchMode=yes -o ConnectTimeout=5 ${PROXMOX_USER}@${PROXMOX_HOST} "echo 'SSH key authentication successful!'" 2>/dev/null; then
    echo ""
    echo "✓ SSH key authentication is working!"
else
    echo ""
    echo "✗ SSH key authentication failed!"
    echo "Please check your configuration and try again."
    exit 1
fi

echo ""
echo "============================================"
echo "SSH Config Setup (Optional)"
echo "============================================"
echo ""
read -p "Add entry to ~/.ssh/config for easier access? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    SSH_CONFIG="$HOME/.ssh/config"

    # Create config if it doesn't exist
    touch "${SSH_CONFIG}"
    chmod 600 "${SSH_CONFIG}"

    # Check if entry already exists
    if grep -q "Host proxmox" "${SSH_CONFIG}"; then
        echo "Entry for 'proxmox' already exists in ~/.ssh/config"
        echo "Please edit it manually if needed."
    else
        echo "" >> "${SSH_CONFIG}"
        echo "# Proxmox Server - Added by setup-ssh-keys.sh" >> "${SSH_CONFIG}"
        echo "Host proxmox" >> "${SSH_CONFIG}"
        echo "    HostName ${PROXMOX_HOST}" >> "${SSH_CONFIG}"
        echo "    User ${PROXMOX_USER}" >> "${SSH_CONFIG}"
        echo "    Port ${PROXMOX_PORT}" >> "${SSH_CONFIG}"
        echo "    IdentityFile ${SSH_KEY_PATH}" >> "${SSH_CONFIG}"
        echo "    ServerAliveInterval 60" >> "${SSH_CONFIG}"
        echo "    ServerAliveCountMax 3" >> "${SSH_CONFIG}"
        echo "" >> "${SSH_CONFIG}"

        echo "✓ Added 'proxmox' entry to ~/.ssh/config"
        echo ""
        echo "You can now connect with just: ssh proxmox"
    fi
fi

echo ""
echo "============================================"
echo "Setup Complete!"
echo "============================================"
echo ""
echo "SSH key location: ${SSH_KEY_PATH}"
echo "Public key: ${SSH_KEY_PATH}.pub"
echo ""
echo "Connect to Proxmox:"
if grep -q "Host proxmox" "$HOME/.ssh/config" 2>/dev/null; then
    echo "  ssh proxmox"
else
    echo "  ssh -i ${SSH_KEY_PATH} ${PROXMOX_USER}@${PROXMOX_HOST}"
fi
echo ""
echo "Or use the helper script:"
echo "  ./connect.sh"
echo ""
echo "IMPORTANT: Keep your private key (${SSH_KEY_PATH}) secure!"
echo "           Never share it or commit it to version control."
echo ""

# Update connect.sh to use key if it exists
if [ -f "connect.sh" ]; then
    echo "Updating connect.sh to use SSH key..."

    cat > connect.sh << SCRIPTEOF
#!/bin/bash
# SSH connection helper for Proxmox server
# Usage: ./connect.sh [command]
# If no command provided, opens interactive shell

PROXMOX_HOST="${PROXMOX_HOST}"
PROXMOX_USER="${PROXMOX_USER}"
PROXMOX_PORT="${PROXMOX_PORT}"
SSH_KEY="${SSH_KEY_PATH}"

# Use SSH key if it exists, otherwise use password auth
if [ -f "\${SSH_KEY}" ]; then
    SSH_OPTS="-i \${SSH_KEY}"
else
    SSH_OPTS=""
fi

if [ \$# -eq 0 ]; then
    echo "Connecting to Proxmox server..."
    ssh -p \${PROXMOX_PORT} \${SSH_OPTS} \${PROXMOX_USER}@\${PROXMOX_HOST}
else
    ssh -p \${PROXMOX_PORT} \${SSH_OPTS} \${PROXMOX_USER}@\${PROXMOX_HOST} "\$@"
fi
SCRIPTEOF

    chmod +x connect.sh
    echo "✓ connect.sh updated to use SSH key"
fi

echo ""
echo "Next steps:"
echo "  1. Test connection: ./connect.sh"
echo "  2. Deploy Minecraft server: ./deploy-all.sh"
