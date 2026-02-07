# Proxmox Project - Key Information

## Server Access
- **Public IP:** <YOUR_SERVER_IP>
- **SSH Port:** 31337 (router forwards to internal port 22)
- **SSH User:** root
- **SSH Key:** /home/gnutgnut/.ssh/id_ed25519
- **Connect:** `./connect.sh` or `./connect.sh "command"`

## Proxmox Host
- **Hostname:** proxmox
- **Internal IP:** 192.168.0.1 (router), PVE on local network
- **Version:** PVE 8.4.16
- **Kernel:** 6.8.12-18-pve

## Minecraft Server (Container 100)
- **Container ID:** 100
- **Hostname:** minecraft-fabric
- **Container IP:** 192.168.0.165 (static DHCP binding)
- **Resources:** 12 cores, 24GB RAM (20GB JVM heap), 100GB disk
- **Game Version:** Minecraft 1.21.4 with Fabric Loader 0.18.4
- **Game Port:** 25565 (forwarded from public IP)
- **RCON Port:** 25575 (internal only)
- **RCON Password:** <CHANGE_ME>
- **Owner/OP:** Detcader_ (UUID: e0c68850-14fa-4f5d-87b5-bf6093326e14)
- **Whitelist:** Enabled
- **MOTD:** §6jee.bz §r- Fabric 1.21.4
- **Watchdog:** Disabled (max-tick-time=-1) for TNT/heavy loads
- **World Seed:** 7749012223296673 (mushroom island near spawn)
- **Backups:** Daily at 4 AM, 7-day retention in `/opt/minecraft/backups/`
- **Offsite:** Weekly (Sundays 5 AM) to Google Drive `minecraft-backups/`, 4-week retention

### Minecraft Management
```bash
# Server control
./connect.sh "pct exec 100 -- systemctl status minecraft"
./connect.sh "pct exec 100 -- systemctl restart minecraft"
./connect.sh "pct exec 100 -- journalctl -u minecraft -f"

# Enter container
./connect.sh "pct enter 100"

# Server files location
/opt/minecraft/
├── server.properties
├── whitelist.json
├── ops.json
├── mods/
└── world/
```

## Web Server (Container 101)
- **Container ID:** 101
- **Hostname:** webserver
- **Container IP:** 192.168.0.105 (static DHCP binding)
- **MAC:** bc:24:11:55:d8:a0
- **Resources:** 2 cores, 2GB RAM, 20GB disk
- **Domain:** https://jee.bz
- **Stack:** Python Flask + Gunicorn + Caddy (auto HTTPS)
- **Ports:** 80, 443 (forwarded from public IP)

### Web Server Management
```bash
# Server control
./connect.sh "pct exec 101 -- systemctl status webapp"
./connect.sh "pct exec 101 -- systemctl status caddy"
./connect.sh "pct exec 101 -- journalctl -u caddy -f"

# App files
/opt/webapp/
├── app.py          # Flask application
├── static/         # Static files (spawn_map.png)
├── venv/           # Python virtual environment
/etc/caddy/Caddyfile  # Caddy config
```

### Spawn Area Map (Top-down)
- **Tool:** unmined v0.19.54 (installed in container 100)
- **Location:** /opt/minecraft/unmined-cli_0.19.54-dev_linux-x64/
- **Shared mount:** /mnt/shared (accessible from both containers)
- **Output:** 512x512 block area centered on spawn (0,0)
- **Cron (MC server):** :27 every hour - renders map to /mnt/shared/spawn_map.png
- **Cron (Web server):** :30 every hour - copies map to /opt/webapp/static/
- **On-demand:** Website has "Refresh" button, calls `/api/render-map` endpoint

Manual render:
```bash
./connect.sh "pct exec 100 -- /opt/minecraft/render_map.sh"
./connect.sh "pct exec 101 -- cp /mnt/shared/spawn_map.png /opt/webapp/static/"
```

### Isometric 3D View (Chunky)
- **Tool:** Chunky 2.4.6 path tracer (installed in container 100)
- **Location:** /opt/chunky/
- **Output:** 640x480 isometric render of spawn area (~8s render time)
- **SPP:** 16 samples per pixel (optimized for speed)
- **Ray depth:** 3 (reduced for speed)
- **Cron:** :28 every hour - renders to /mnt/shared/spawn_detail.png
- **On-demand:** Website "Refresh" button calls `/api/render-detail`
- **Camera controls:** N/S/E/W pan, zoom in/out, reset - with debounced rendering
- **Camera state:** Persisted in `/opt/chunky/camera_state`
- **Fallback:** If Chunky fails, falls back to unmined with 3D shadows

Key files:
- `/opt/chunky/ChunkyLauncher.jar` - Launcher (downloads core on first run)
- `/opt/chunky/resources/minecraft.jar` - MC 1.21.4 textures
- `/opt/chunky/scenes/spawn_isometric.json` - Scene configuration (auto-generated)
- `/opt/minecraft/render_isometric.sh` - Render script (accepts comma-separated moves)
- `/opt/chunky/camera_state` - Current camera position (CAM_X, CAM_Z, FOV)

Manual render:
```bash
./connect.sh "pct exec 100 -- /opt/minecraft/render_isometric.sh"
./connect.sh "pct exec 100 -- /opt/minecraft/render_isometric.sh n,n,e"  # Move then render
./connect.sh "pct exec 101 -- cp /mnt/shared/spawn_detail.png /opt/webapp/static/"
```

## Security Configuration
- **fail2ban:** Installed, protecting SSH (24h ban) and PVE web UI (1h ban)
- **fail2ban ignore list:** 192.168.0.0/24 (LAN/containers) in `/etc/fail2ban/jail.local`
- **Minecraft:** online-mode=true, whitelist enabled, command blocks enabled
- **Port forwarding:** Only 25565 (Minecraft) exposed; RCON (25575) internal only
- **SSH:** Key-based auth working, root login still enabled (consider hardening)

### Container-to-Host SSH (for on-demand map render)
Web container (101) can SSH to Proxmox host to trigger commands:
- SSH key generated in container: `/opt/webapp/.ssh/id_ed25519`
- Key added to host's `/root/.ssh/authorized_keys`
- Proxmox host IP from containers: 192.168.0.124
- Used by Flask `/api/render-map` endpoint to trigger unmined on container 100

## Network Notes
- **Domain:** jee.bz (DynDNS configured)
- Router admin accessible via SSH tunnel: `ssh -L 8080:192.168.0.1:80 ...`
- Port forwarding (router → PVE → container):
  - 25565 → 192.168.0.165 (Minecraft)
  - 80, 443 → 192.168.0.105 (Web server)
- Static DHCP bindings: .165 (MC), .105 (web)

### iptables Configuration (Critical)
Container NICs must have `firewall=0` to allow inter-container communication:
```bash
pct set 100 --net0 name=eth0,bridge=vmbr0,firewall=0,...
pct set 101 --net0 name=eth0,bridge=vmbr0,firewall=0,...
```

iptables rules must exclude LAN traffic to allow containers to reach internet:
```bash
iptables -t nat -A PREROUTING ! -s 192.168.0.0/24 -p tcp --dport 25565 -j DNAT --to-destination 192.168.0.165:25565
iptables -t nat -A PREROUTING ! -s 192.168.0.0/24 -p tcp --dport 80 -j DNAT --to-destination 192.168.0.105:80
iptables -t nat -A PREROUTING ! -s 192.168.0.0/24 -p tcp --dport 443 -j DNAT --to-destination 192.168.0.105:443
```
Rules saved in `/etc/iptables/rules.v4`

## Java Installation (Container)
Debian 12 doesn't have openjdk-21 in default repos. Use Adoptium:
```bash
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg
echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" > /etc/apt/sources.list.d/adoptium.list
apt-get update && apt-get install -y temurin-21-jdk
```

## Useful Commands
```bash
# Check Minecraft server status from internet
curl -s "https://api.mcsrvstat.us/3/<YOUR_SERVER_IP>:25565"

# List containers
./connect.sh "pct list"

# Check fail2ban status
./connect.sh "fail2ban-client status sshd"

# Create new world with specific seed
./connect.sh "pct exec 100 -- systemctl stop minecraft"
./connect.sh "pct exec 100 -- mv /opt/minecraft/world /opt/minecraft/world_backup"
./connect.sh "pct exec 100 -- sed -i 's/^level-seed=.*/level-seed=YOUR_SEED/' /opt/minecraft/server.properties"
./connect.sh "pct exec 100 -- systemctl start minecraft"
```

## Key Learnings & Patterns

### Using connect.sh
Always use `./connect.sh` for SSH commands to the Proxmox host:
```bash
# Single command
./connect.sh "pct exec 100 -- systemctl status minecraft"

# Piping content to container
cat localfile.sh | ./connect.sh "pct exec 100 -- tee /opt/minecraft/script.sh > /dev/null"

# Multiple commands in container
./connect.sh "pct exec 100 -- bash -c 'command1 && command2'"
```

### Gunicorn Timeout
Long-running API endpoints (like Chunky renders) require increased gunicorn timeout:
- Default is 30s, renders can take 60-300s
- Set `--timeout 600` in `/etc/systemd/system/webapp.service`
- Run `systemctl daemon-reload && systemctl restart webapp` after changes

### Chunky Headless Rendering
- Always clear scene files before render to avoid ghosting: `rm -f ${SCENE_DIR}/${SCENE_NAME}*`
- Use `-f` flag to force render without existing octree
- Camera state persists between renders via simple key=value file
- Reduce SPP (16), resolution (640x480), and ray depth (3) for faster renders

### Debouncing UI Actions
For expensive operations triggered by UI:
- Update UI immediately (optimistic)
- Queue actions and wait for idle period (1s)
- Batch all queued actions into single operation
- Script handles comma-separated commands: `render.sh n,n,e,w`

### Container Communication
- Containers share `/mnt/shared` bind mount for file passing
- Web container SSHs to Proxmox host (192.168.0.124) to trigger commands on MC container
- Webapp user's SSH keys in `/opt/webapp/.ssh/`

### Common Issues
- **fail2ban blocking containers:** Add 192.168.0.0/24 to ignoreip in `/etc/fail2ban/jail.local`
- **ImageMagick in webapp container:** Not installed - use MC container for image processing
- **New world with few chunks:** Only spawn chunks generated until players explore
