# Quick Start Guide

## Prerequisites

- Proxmox server accessible at `jee.bz:8006`
- SSH access (password or key-based)
- SSH and web portal ports open (22, 8006)

### SSH Key Setup (Recommended First Step)

Before deploying, set up SSH keys for passwordless authentication:

```bash
# Choose your platform:
./setup-ssh-keys.sh    # Git Bash/WSL/Linux/Mac
.\setup-ssh-keys.ps1   # Windows PowerShell
```

This eliminates password prompts during deployment. See [SSH-SETUP.md](SSH-SETUP.md) for details.

## Option 1: Automated Deployment (Recommended)

Run everything in one go from your local machine:

```bash
# Make scripts executable
chmod +x *.sh

# Run pre-flight check (recommended!)
./pre-flight-check.sh

# If pre-flight passes, deploy
./deploy-all.sh
```

This will automatically:
1. Upload all scripts to Proxmox
2. Create the container
3. Configure Proxmox firewall rules
4. Install Minecraft with mods
5. Set up web panel
6. Configure backups

**Total time**: ~15-20 minutes

## Option 2: Manual Step-by-Step

### Step 1: Connect to Proxmox

```bash
chmod +x connect.sh
./connect.sh
```

### Step 2: Create Container

```bash
# On Proxmox host
bash /root/deploy-container.sh
```

**Note**: Edit `deploy-container.sh` first if you need to change:
- Container ID (default: 100)
- Storage pool (default: local-lvm)
- Network settings

### Step 2.5: Configure Firewall

```bash
# On Proxmox host
bash /root/configure-firewall.sh
```

This configures Proxmox firewall to allow Minecraft and web panel ports.

### Step 3: Install Minecraft

```bash
# Enter container
pct enter 100

# Run installation
bash /root/minecraft-setup.sh
```

When prompted, type `y` to start the server immediately.

### Step 4: Connect and Play

In Minecraft client:
- Click "Multiplayer"
- Add Server: `jee.bz:25565`
- Join and play!

## Post-Installation

### Make Yourself Admin

```bash
# Enter container
pct enter 100

# Connect to server console (option 1: RCON)
rcon-cli --host localhost --port 25575 --password YOUR_RCON_PASSWORD
> op YOUR_MINECRAFT_USERNAME

# OR option 2: Edit ops.json directly
systemctl stop minecraft
nano /opt/minecraft/ops.json
# Add: {"uuid":"YOUR_UUID","name":"YOUR_USERNAME","level":4}
systemctl start minecraft
```

### Install Web Panel (Optional)

```bash
# Inside container
bash /root/pterodactyl-setup.sh
```

Access at: `http://jee.bz:24444`
- Username: `admin`
- Password: `123456` (CHANGE IMMEDIATELY!)

### Set Up Backups

```bash
# Inside container
bash /root/backup-setup.sh
```

Backups will run daily at 3 AM automatically.

## First Configuration

### Essential Settings

Edit `/opt/minecraft/server.properties`:

```properties
# Change these:
motd=Your Custom Server Name
difficulty=normal
max-players=10
white-list=false  # Set to true for private server

# Recommended for better performance:
view-distance=16
simulation-distance=12
```

Restart after changes:
```bash
systemctl restart minecraft
```

### Add Mods

```bash
cd /opt/minecraft/mods/

# Download from Modrinth or CurseForge
wget MOD_DOWNLOAD_URL

# Fix permissions
chown minecraft:minecraft *.jar

# Restart
systemctl restart minecraft
```

## Troubleshooting

### Can't connect to server

1. Run port check script:
```bash
bash check-ports.sh
```

2. Check Proxmox firewall:
```bash
# On Proxmox host
pve-firewall status
cat /etc/pve/firewall/100.fw
```

3. Check container firewall:
```bash
pct exec 100 -- ufw status
```

4. Verify server is running:
```bash
pct exec 100 -- systemctl status minecraft
```

5. Check port forwarding on your router (if needed)

### Server crashes or won't start

```bash
# View error logs
pct exec 100 -- journalctl -u minecraft -n 50
```

Common fixes:
- Remove incompatible mods
- Increase heap size in `start.sh`
- Check Java version: `java -version`

### Poor performance

1. Reduce view distance in `server.properties`
2. Remove heavy mods
3. Increase heap size (edit `/opt/minecraft/start.sh`)
4. Check system resources: `pct exec 100 -- htop`

## Useful Commands

### Container Management (from Proxmox)

```bash
pct start 100          # Start container
pct stop 100           # Stop container
pct enter 100          # Open shell in container
pct exec 100 -- COMMAND  # Run command in container
```

### Server Management (inside container)

```bash
systemctl start minecraft     # Start server
systemctl stop minecraft      # Stop server
systemctl restart minecraft   # Restart server
systemctl status minecraft    # Check status
journalctl -u minecraft -f   # View live logs
```

### Monitoring

```bash
# Run monitoring script
bash /root/monitoring.sh

# Or individual commands
htop                    # System resources
journalctl -u minecraft -f   # Server logs
tail -f /opt/minecraft/logs/latest.log  # Minecraft logs
```

## Server Information

- **Container**: LXC (unprivileged)
- **OS**: Debian 12
- **Java**: OpenJDK 21
- **Minecraft**: Latest (1.21.4 by default)
- **Mod Loader**: Fabric
- **RAM**: 16GB allocated, 12GB heap
- **CPU**: 8 cores
- **Storage**: 100GB

## URLs & Ports

| Service | Address | Credentials |
|---------|---------|-------------|
| Minecraft | `jee.bz:25565` | - |
| MCSManager | `http://jee.bz:24444` | admin/123456 |
| Proxmox Web | `https://jee.bz:8006` | Your Proxmox creds |

## Need Help?

- Full documentation: `README.md`
- Backup restoration: `/var/backups/minecraft/RESTORE.md`
- Server logs: `journalctl -u minecraft -f`
- System health: `bash /root/monitoring.sh`

## Next Steps

1. ✅ Server is running
2. ⏭️ Add yourself as operator
3. ⏭️ Install additional mods
4. ⏭️ Configure whitelist (optional)
5. ⏭️ Set up Discord bot (optional)
6. ⏭️ Install plugins like Dynmap (optional)
7. ⏭️ Share server IP with friends!

---

**Pro tip**: Take a Proxmox snapshot before making major changes:
```bash
# On Proxmox host
pct snapshot 100 before-changes
```
