# SSH Key-Based Authentication Setup for Proxmox (PowerShell version)
# Run this script in PowerShell on Windows

$PROXMOX_HOST = "proxmox.cbmcra.website"
$PROXMOX_USER = "root"
$PROXMOX_PORT = "22"
$SSH_DIR = "$env:USERPROFILE\.ssh"
$SSH_KEY_PATH = "$SSH_DIR\id_ed25519"
$SSH_KEY_NAME = "proxmox-claude-code"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SSH Key-Based Authentication Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target server: $PROXMOX_USER@$PROXMOX_HOST"
Write-Host ""

# Create .ssh directory if it doesn't exist
if (-not (Test-Path $SSH_DIR)) {
    Write-Host "Creating .ssh directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $SSH_DIR | Out-Null
}

# Check if SSH key exists
if (Test-Path $SSH_KEY_PATH) {
    Write-Host "SSH key already exists at: $SSH_KEY_PATH" -ForegroundColor Yellow
    Write-Host ""
    $useExisting = Read-Host "Use existing key? (y/n)"

    if ($useExisting -notmatch '^[Yy]$') {
        Write-Host "Creating new key with custom name..." -ForegroundColor Yellow
        $SSH_KEY_PATH = "$SSH_DIR\$SSH_KEY_NAME"

        if (Test-Path $SSH_KEY_PATH) {
            Write-Host "Key $SSH_KEY_PATH already exists!" -ForegroundColor Red
            Write-Host "Please remove it or choose a different name."
            exit 1
        }

        ssh-keygen -t ed25519 -f $SSH_KEY_PATH -C "$SSH_KEY_NAME@$env:COMPUTERNAME"
    }
} else {
    Write-Host "No SSH key found. Generating new Ed25519 key..." -ForegroundColor Yellow
    Write-Host ""

    ssh-keygen -t ed25519 -f $SSH_KEY_PATH -C "$SSH_KEY_NAME@$env:COMPUTERNAME"
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Copying Public Key to Proxmox" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "You will be prompted for your Proxmox root password..." -ForegroundColor Yellow
Write-Host ""

# Read public key
$pubKey = Get-Content "$SSH_KEY_PATH.pub" -Raw

# Copy public key to Proxmox
$sshCommand = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
ssh -p $PROXMOX_PORT "$PROXMOX_USER@$PROXMOX_HOST" $sshCommand

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Testing Connection" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Test connection
Write-Host "Testing SSH connection without password..." -ForegroundColor Yellow
$testResult = ssh -p $PROXMOX_PORT -i $SSH_KEY_PATH -o BatchMode=yes -o ConnectTimeout=5 "$PROXMOX_USER@$PROXMOX_HOST" "echo 'SSH key authentication successful!'" 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ SSH key authentication is working!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "✗ SSH key authentication failed!" -ForegroundColor Red
    Write-Host "Please check your configuration and try again."
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SSH Config Setup (Optional)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
$setupConfig = Read-Host "Add entry to ~/.ssh/config for easier access? (y/n)"

if ($setupConfig -match '^[Yy]$') {
    $SSH_CONFIG = "$SSH_DIR\config"

    # Create config if it doesn't exist
    if (-not (Test-Path $SSH_CONFIG)) {
        New-Item -ItemType File -Path $SSH_CONFIG | Out-Null
    }

    # Check if entry already exists
    $configContent = Get-Content $SSH_CONFIG -Raw -ErrorAction SilentlyContinue

    if ($configContent -match "Host proxmox") {
        Write-Host "Entry for 'proxmox' already exists in ~/.ssh/config" -ForegroundColor Yellow
        Write-Host "Please edit it manually if needed."
    } else {
        $configEntry = @"

# Proxmox Server - Added by setup-ssh-keys.ps1
Host proxmox
    HostName $PROXMOX_HOST
    User $PROXMOX_USER
    Port $PROXMOX_PORT
    IdentityFile $SSH_KEY_PATH
    ServerAliveInterval 60
    ServerAliveCountMax 3

"@
        Add-Content -Path $SSH_CONFIG -Value $configEntry

        Write-Host "✓ Added 'proxmox' entry to ~/.ssh/config" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now connect with just: ssh proxmox"
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "SSH key location: $SSH_KEY_PATH"
Write-Host "Public key: $SSH_KEY_PATH.pub"
Write-Host ""
Write-Host "Connect to Proxmox:"
if ((Get-Content "$SSH_DIR\config" -Raw -ErrorAction SilentlyContinue) -match "Host proxmox") {
    Write-Host "  ssh proxmox" -ForegroundColor Green
} else {
    Write-Host "  ssh -i $SSH_KEY_PATH $PROXMOX_USER@$PROXMOX_HOST" -ForegroundColor Green
}
Write-Host ""
Write-Host "IMPORTANT: Keep your private key ($SSH_KEY_PATH) secure!" -ForegroundColor Yellow
Write-Host "           Never share it or commit it to version control." -ForegroundColor Yellow
Write-Host ""

Write-Host "Next steps:"
Write-Host "  1. Test connection: ssh proxmox (or use connect.sh in Git Bash)"
Write-Host "  2. Deploy Minecraft server: bash deploy-all.sh (in Git Bash/WSL)"
