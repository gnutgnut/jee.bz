#!/bin/bash
# Pre-flight Check Script
# Run this before deploy-all.sh to validate configuration

set -e

PROXMOX_HOST="jee.bz"
PROXMOX_USER="root"
CTID=100
REQUIRED_SCRIPTS="deploy-container.sh minecraft-setup.sh configure-firewall.sh backup-setup.sh pterodactyl-setup.sh"

echo "============================================"
echo "Pre-Flight Check"
echo "============================================"
echo ""

ERRORS=0
WARNINGS=0

# Check 1: SSH connectivity
echo "[1/8] Checking SSH connectivity to Proxmox..."
if ssh -o BatchMode=yes -o ConnectTimeout=5 ${PROXMOX_USER}@${PROXMOX_HOST} "echo 'Connection successful'" >/dev/null 2>&1; then
    echo "  ✓ SSH connection successful"
else
    echo "  ✗ Cannot connect to Proxmox via SSH"
    echo "    Run ./setup-ssh-keys.sh first"
    ERRORS=$((ERRORS + 1))
fi

# Check 2: Required scripts exist locally
echo "[2/8] Checking required scripts exist..."
for script in $REQUIRED_SCRIPTS; do
    if [ -f "$script" ]; then
        echo "  ✓ $script found"
    else
        echo "  ✗ $script missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check 3: Scripts are executable
echo "[3/8] Checking scripts are executable..."
for script in $REQUIRED_SCRIPTS connect.sh; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo "  ✓ $script is executable"
        else
            echo "  ! $script not executable (run: chmod +x *.sh)"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
done

# Check 4: Container ID availability
echo "[4/8] Checking if container ID ${CTID} is available..."
if ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pct status ${CTID}" >/dev/null 2>&1; then
    echo "  ✗ Container ${CTID} already exists!"
    echo "    Either destroy it or change CTID in deploy-container.sh"
    ERRORS=$((ERRORS + 1))
else
    echo "  ✓ Container ID ${CTID} is available"
fi

# Check 5: Storage pool validation
echo "[5/8] Checking storage pools..."
STORAGE_POOLS=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pvesm status | tail -n +2 | awk '{print \$1}'" 2>/dev/null)
if echo "$STORAGE_POOLS" | grep -q "local-lvm"; then
    echo "  ✓ Storage pool 'local-lvm' exists"
else
    echo "  ! Storage pool 'local-lvm' not found"
    echo "    Available pools:"
    echo "$STORAGE_POOLS" | sed 's/^/      /'
    echo "    Update STORAGE in deploy-container.sh if needed"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 6: Template availability
echo "[6/8] Checking Debian template..."
if ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pveam list local | grep -q debian-12-standard" 2>/dev/null; then
    echo "  ✓ Debian 12 template found"
else
    echo "  ! Debian 12 template not found (will be downloaded automatically)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 7: Network configuration
echo "[7/8] Checking network bridge..."
if ssh ${PROXMOX_USER}@${PROXMOX_HOST} "ip link show vmbr0" >/dev/null 2>&1; then
    echo "  ✓ Network bridge vmbr0 exists"
else
    echo "  ✗ Network bridge vmbr0 not found"
    echo "    Check network configuration or update deploy-container.sh"
    ERRORS=$((ERRORS + 1))
fi

# Check 8: System resources
echo "[8/8] Checking Proxmox resources..."
TOTAL_RAM=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "free -m | awk '/^Mem:/{print \$2}'" 2>/dev/null)
TOTAL_CORES=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "nproc" 2>/dev/null)

if [ -n "$TOTAL_RAM" ] && [ "$TOTAL_RAM" -ge 16384 ]; then
    echo "  ✓ RAM: ${TOTAL_RAM}MB (sufficient for 16GB container)"
else
    echo "  ! RAM: ${TOTAL_RAM}MB (may not be enough for 16GB container)"
    echo "    Consider reducing MEMORY in deploy-container.sh"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -n "$TOTAL_CORES" ] && [ "$TOTAL_CORES" -ge 8 ]; then
    echo "  ✓ CPU Cores: ${TOTAL_CORES} (sufficient for 8-core container)"
else
    echo "  ! CPU Cores: ${TOTAL_CORES} (may not be enough)"
    echo "    Consider reducing CORES in deploy-container.sh"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "============================================"
echo "Summary"
echo "============================================"
echo "Errors: ${ERRORS}"
echo "Warnings: ${WARNINGS}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo "✗ Pre-flight check FAILED"
    echo "  Please fix errors before running deploy-all.sh"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo "! Pre-flight check passed with warnings"
    echo "  Review warnings above before proceeding"
    echo ""
    read -p "Continue with deployment anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        exit 0
    fi
else
    echo "✓ Pre-flight check PASSED"
    echo "  Ready to deploy!"
fi

echo ""
echo "To deploy, run: ./deploy-all.sh"
