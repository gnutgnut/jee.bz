# SSH Key-Based Authentication Setup

This guide will help you set up SSH key-based authentication to your Proxmox server, eliminating the need to enter passwords.

## Quick Setup

### Option 1: Automated (Bash - Git Bash/WSL/Linux/Mac)

```bash
chmod +x setup-ssh-keys.sh
./setup-ssh-keys.sh
```

### Option 2: Automated (PowerShell - Windows)

```powershell
.\setup-ssh-keys.ps1
```

### Option 3: Manual Setup

#### 1. Generate SSH Key Pair

**On Windows (PowerShell):**
```powershell
ssh-keygen -t ed25519 -C "proxmox-access"
```

**On Linux/Mac/WSL/Git Bash:**
```bash
ssh-keygen -t ed25519 -C "proxmox-access"
```

When prompted:
- Press Enter to save to default location (`~/.ssh/id_ed25519`)
- Enter a passphrase (optional but recommended)

#### 2. Copy Public Key to Proxmox

**Method A: Using ssh-copy-id (Linux/Mac/WSL/Git Bash)**
```bash
ssh-copy-id root@jee.bz
```

**Method B: Manual (Windows PowerShell or if ssh-copy-id not available)**
```powershell
# Read your public key
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub

# SSH to Proxmox and paste the key
ssh root@jee.bz

# On Proxmox, run:
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
# Paste your public key, save and exit (Ctrl+X, Y, Enter)
chmod 600 ~/.ssh/authorized_keys
exit
```

**Method C: One-liner (Git Bash/WSL)**
```bash
cat ~/.ssh/id_ed25519.pub | ssh root@jee.bz "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

#### 3. Test Connection

```bash
ssh root@jee.bz
```

You should connect without entering a password!

## SSH Config Setup (Optional but Recommended)

Add this to `~/.ssh/config` for easier access:

**Location:**
- Windows: `C:\Users\YourUsername\.ssh\config`
- Linux/Mac: `~/.ssh/config`

**Content:**
```
Host proxmox
    HostName jee.bz
    User root
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

**Now you can connect with just:**
```bash
ssh proxmox
```

## Verification

After setup, verify everything works:

```bash
# Test SSH connection
ssh proxmox "hostname && uptime"

# Test with deploy scripts
./connect.sh

# Test file transfer
scp test-file.txt proxmox:/root/
```

## Troubleshooting

### "Permission denied (publickey)"

1. Check key permissions:
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

2. Verify key is in authorized_keys on Proxmox:
```bash
ssh root@jee.bz "cat ~/.ssh/authorized_keys"
```

3. Check Proxmox SSH config allows key authentication:
```bash
ssh root@jee.bz "grep -E 'PubkeyAuthentication|PasswordAuthentication' /etc/ssh/sshd_config"
```

Should show:
```
PubkeyAuthentication yes
```

### "Host key verification failed"

First time connecting to a new host:
```bash
ssh-keygen -R jee.bz
ssh root@jee.bz
# Type 'yes' when prompted
```

### SSH agent not running (Windows)

Start the SSH Agent service:
```powershell
# PowerShell (Run as Administrator)
Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent

# Add your key to the agent
ssh-add $env:USERPROFILE\.ssh\id_ed25519
```

### Connection timeout

Check firewall:
```bash
# On Proxmox
ufw status
# Should show port 22 allowed, or firewall disabled
```

## Security Best Practices

### 1. Use a Passphrase
Protect your private key with a passphrase:
```bash
ssh-keygen -p -f ~/.ssh/id_ed25519
```

### 2. Use SSH Agent
Store unlocked key in memory:
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### 3. Disable Password Authentication (After Testing)

Once SSH keys work, disable password auth on Proxmox:
```bash
# On Proxmox
nano /etc/ssh/sshd_config

# Change these lines:
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no

# Restart SSH
systemctl restart sshd
```

**WARNING:** Only do this after confirming SSH key auth works!

### 4. Restrict SSH Access by IP (Optional)

Add to Proxmox firewall or SSH config:
```bash
# In /etc/ssh/sshd_config
AllowUsers root@YOUR_IP_ADDRESS
```

### 5. Backup Your Keys

```bash
# Backup private key to secure location
cp ~/.ssh/id_ed25519 /path/to/secure/backup/
# Encrypt it
gpg -c /path/to/secure/backup/id_ed25519
```

## Multiple Keys (Advanced)

If you need different keys for different purposes:

```bash
# Generate new key with custom name
ssh-keygen -t ed25519 -f ~/.ssh/proxmox_minecraft -C "minecraft-management"

# Add to SSH config
Host proxmox-minecraft
    HostName jee.bz
    User root
    IdentityFile ~/.ssh/proxmox_minecraft
```

## Next Steps

Once SSH keys are set up:

1. ✅ Test connection: `ssh proxmox`
2. ✅ Run deployment: `./deploy-all.sh`
3. ✅ Scripts will now run without password prompts
4. ✅ (Optional) Disable password authentication on Proxmox

## For Claude Code Access

When running Claude Code on Proxmox, it will have direct local access to all `pvesh`, `pct`, and `qm` commands without needing SSH at all - even more secure!

Your local SSH keys are just for:
- Deploying from your Windows machine
- Managing the Proxmox host remotely
- Transferring files back and forth
