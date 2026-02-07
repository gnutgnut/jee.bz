# Minecraft Fabric Server on Proxmox

High-performance Minecraft Fabric server running in Proxmox LXC container with web management, automated backups, and monitoring.

## Server Specifications

- **Container**: LXC (Debian 12)
- **Resources**: 16GB RAM, 8 CPU cores, 100GB storage
- **Minecraft**: Java Edition with Fabric mod loader
- **Performance Mods**: Lithium, Starlight, FerriteCore, C2ME
- **JVM Heap**: 12GB with optimized G1GC settings
- **Management**: MCSManager web panel
- **Backups**: Automated daily world backups + Proxmox snapshots

## Prerequisites

### SSH Key Setup (Recommended)

Set up SSH key-based authentication for passwordless access:

```bash
# Automated setup
./setup-ssh-keys.sh    # Linux/Mac/WSL/Git Bash
# OR
.\setup-ssh-keys.ps1   # Windows PowerShell
```

See [SSH-SETUP.md](SSH-SETUP.md) for detailed instructions.

## Quick Start

### 1. Deploy Container on Proxmox

```bash
# Automated deployment (recommended)
./deploy-all.sh

# OR manual deployment:
# Copy deployment script to Proxmox
scp deploy-container.sh root@proxmox.cbmcra.website:/root/

# SSH into Proxmox
ssh root@proxmox.cbmcra.website

# Run deployment (review script first and adjust CTID/storage if needed)
bash /root/deploy-container.sh
```

### 2. Install Minecraft Server

```bash
# Copy setup script to container
pct push 100 minecraft-setup.sh /root/minecraft-setup.sh

# Enter container
pct enter 100

# Run Minecraft installation
bash /root/minecraft-setup.sh
```

### 3. Install Web Management Panel (Optional)

```bash
# Inside container
bash /root/pterodactyl-setup.sh
```

Access at: `http://YOUR_SERVER_IP:24444`

### 4. Set Up Automated Backups

```bash
# Inside container
bash /root/backup-setup.sh

# On Proxmox host (for container snapshots)
# Add to crontab: 0 2 * * * /root/backup-minecraft-container.sh
```

## Server Management

### Service Control

```bash
# Start server
systemctl start minecraft

# Stop server
systemctl stop minecraft

# Restart server
systemctl restart minecraft

# View logs
journalctl -u minecraft -f

# Check status
systemctl status minecraft
```

### Server Files

- **Config**: `/opt/minecraft/server.properties`
- **Mods**: `/opt/minecraft/mods/`
- **Worlds**: `/opt/minecraft/world/`, `world_nether/`, `world_the_end/`
- **Logs**: `/opt/minecraft/logs/`
- **Startup**: `/opt/minecraft/start.sh`

### Configuration Changes

**Edit server properties:**
```bash
nano /opt/minecraft/server.properties
systemctl restart minecraft
```

**Change Minecraft version:**
```bash
systemctl stop minecraft
cd /opt/minecraft
# Edit version in start.sh or re-run fabric installer
java -jar fabric-installer.jar server -mcversion NEW_VERSION
systemctl start minecraft
```

**Add mods:**
```bash
cd /opt/minecraft/mods/
wget MOD_DOWNLOAD_URL
chown minecraft:minecraft *.jar
systemctl restart minecraft
```

### Port Configuration

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| Minecraft | 25565 | TCP | Game server |
| RCON | 25575 | TCP | Remote console |
| MCSManager Web | 24444 | TCP | Web panel |
| MCSManager Daemon | 23333 | TCP | Panel backend |

**Proxmox Firewall**: Configured automatically by `configure-firewall.sh` script.

To verify ports are accessible:
```bash
bash check-ports.sh
```

## Performance Tuning

### Current JVM Settings (12GB heap)

The server uses Aikar's flags optimized for 12GB heap:
- G1 garbage collector with tuned pause times
- Large heap for extensive chunk loading and mods
- Optimized for consistent TPS with minimal lag spikes

**To adjust heap size**, edit `/opt/minecraft/start.sh`:
```bash
# For 8GB heap
-Xms8G -Xmx8G

# For 16GB heap (if you want to use more RAM)
-Xms16G -Xmx16G
```

### Server Properties Tuning

**View distance** (default: 16):
```properties
view-distance=16  # Increase for better visibility, decrease for performance
simulation-distance=12  # Mob/crop ticking distance
```

**Network compression** (default: 256):
```properties
network-compression-threshold=256  # Lower = more CPU, less bandwidth
```

## Backups

### Automated Backups

- **World backups**: Daily at 3:00 AM (7-day retention)
- **Location**: `/var/backups/minecraft/`
- **Log**: `/var/log/minecraft-backup.log`

### Manual Backup

```bash
# World backup
/usr/local/bin/backup-minecraft-world.sh

# Container snapshot (on Proxmox host)
/root/backup-minecraft-container.sh
```

### Restore from Backup

See `/var/backups/minecraft/RESTORE.md` for detailed restoration instructions.

Quick restore:
```bash
systemctl stop minecraft
cd /opt/minecraft
tar -xzf /var/backups/minecraft/minecraft-world-TIMESTAMP.tar.gz
chown -R minecraft:minecraft /opt/minecraft
systemctl start minecraft
```

## Monitoring

### View Server Status

```bash
# System resources
htop

# Server logs
journalctl -u minecraft -f

# Backup logs
tail -f /var/log/minecraft-backup.log

# Container stats (from Proxmox)
pct exec 100 -- htop
```

### Performance Metrics

```bash
# TPS and memory usage (in server console)
/forge tps

# Or check logs for performance warnings
journalctl -u minecraft | grep -i "running.*behind"
```

## Troubleshooting

### Server Won't Start

```bash
# Check logs
journalctl -u minecraft -n 50

# Common issues:
# - Java not installed: apt-get install openjdk-21-jdk-headless
# - Permission issues: chown -R minecraft:minecraft /opt/minecraft
# - Port in use: lsof -i :25565
```

### Poor Performance

1. Check TPS in server console
2. Review mod compatibility
3. Reduce view-distance in server.properties
4. Check system resources: `htop`
5. Review garbage collection logs

### Connection Issues

```bash
# Check firewall
ufw status

# Test port accessibility (from Proxmox host)
nc -zv localhost 25565

# Check if server is listening
ss -tlnp | grep 25565
```

### Mod Issues

```bash
# Remove problematic mod
systemctl stop minecraft
rm /opt/minecraft/mods/problematic-mod.jar
systemctl start minecraft

# Check mod compatibility
# Ensure all mods are for same Minecraft + Fabric version
```

## Security Notes

### Important: Change Default Passwords

```bash
# RCON password (in server.properties)
nano /opt/minecraft/server.properties
# Change: rcon.password=minecraft_rcon_password_change_me

# Container root password
passwd

# MCSManager admin password (change in web UI)
```

### Firewall Configuration

The firewall (ufw) is configured to only allow:
- Minecraft (25565)
- RCON (25575)
- MCSManager (23333, 24444)

To add SSH access from specific IP:
```bash
ufw allow from YOUR_IP to any port 22
```

### Enable Whitelist (Recommended)

```bash
# Edit server.properties
white-list=true

# Add players in-game or via file
nano /opt/minecraft/whitelist.json
systemctl restart minecraft
```

## Advanced Configuration

### Pre-generate World Chunks

Reduces lag during gameplay:
```bash
# Install chunky mod
cd /opt/minecraft/mods
wget https://cdn.modrinth.com/data/fALzjamp/versions/VERSION/Chunky-Fabric-VERSION.jar

# In-game or console, run:
/chunky radius 5000
/chunky start
```

### RCON Remote Management

Install `rcon-cli` for remote console access:
```bash
# Install
apt-get install -y build-essential
git clone https://github.com/itzg/rcon-cli.git
cd rcon-cli && make && make install

# Use
rcon-cli --host localhost --port 25575 --password YOUR_RCON_PASSWORD
```

### Install Additional Mods

Visit [Modrinth](https://modrinth.com/) or [CurseForge](https://www.curseforge.com/minecraft/mc-mods):
1. Find mod compatible with your Minecraft version
2. Download Fabric version
3. Upload to `/opt/minecraft/mods/`
4. Restart server

Popular mods:
- **Fabric API** (required for most mods) - Already installed
- **Lithium** (performance) - Already installed
- **Phosphor/Starlight** (lighting optimization) - Already installed
- **Dynmap** (web-based world map)
- **Essentials** (admin commands)

## Container Management (Proxmox)

```bash
# Start container
pct start 100

# Stop container
pct stop 100

# Enter container
pct enter 100

# Push file to container
pct push 100 /path/to/local/file /path/in/container

# Pull file from container
pct pull 100 /path/in/container /path/to/local

# Resize disk
pct resize 100 rootfs +50G

# Change resources
pct set 100 -memory 20480 -cores 12
```

## Network Configuration

### Port Forwarding (if behind router)

Forward these ports to your Proxmox server IP:
- `25565` (TCP) - Minecraft
- `24444` (TCP) - Web panel (optional)

### Static IP Configuration

If you want a static IP instead of DHCP:

1. Edit container network:
```bash
# On Proxmox host
pct set 100 -net0 name=eth0,bridge=vmbr0,ip=192.168.1.100/24,gw=192.168.1.1
```

2. Restart container:
```bash
pct restart 100
```

## Useful Scripts

All scripts are in `/root/` of the container:

- `minecraft-setup.sh` - Initial Minecraft installation
- `pterodactyl-setup.sh` - Web panel installation
- `backup-setup.sh` - Backup automation setup
- `/usr/local/bin/backup-minecraft-world.sh` - Manual world backup

## Support & Resources

- **Fabric Wiki**: https://fabricmc.net/wiki/
- **Paper Docs** (for performance tips): https://docs.papermc.io/
- **Aikar's Flags**: https://aikar.co/mcflags.html
- **Minecraft Wiki**: https://minecraft.wiki/
- **MCSManager**: https://mcsmanager.com/

## Credits

- Server configuration based on Aikar's optimized JVM flags
- Performance mods from the Fabric community
- Deployment scripts created for Proxmox LXC environment

---

**Server**: proxmox.cbmcra.website:8006
**Container ID**: 100
**Minecraft Port**: 25565
**Management Panel**: http://YOUR_IP:24444
