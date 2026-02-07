# Disaster Recovery Setup Guide

This guide documents how to recreate the jee.bz Minecraft + Web infrastructure on a fresh Proxmox VE installation.

## Prerequisites

- Proxmox VE 8.x installed
- Public IP with ports 22, 80, 443, 25565 forwarded
- Domain (jee.bz) pointing to the public IP
- SSH key for access

## 1. Proxmox Host Setup

### Install Required Packages
```bash
apt update
apt install -y fail2ban iptables-persistent
```

### Configure fail2ban
Copy `proxmox-host/jail.local` to `/etc/fail2ban/jail.local`:
```bash
systemctl restart fail2ban
```

### Configure iptables
Copy `proxmox-host/iptables-rules.v4` to `/etc/iptables/rules.v4`:
```bash
iptables-restore < /etc/iptables/rules.v4
```

### Create Shared Mount
```bash
mkdir -p /mnt/shared
```

## 2. Minecraft Container (100)

### Create Container
```bash
pct create 100 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
    --hostname minecraft-fabric \
    --memory 24576 \
    --cores 12 \
    --rootfs local-lvm:100 \
    --net0 name=eth0,bridge=vmbr0,firewall=0,ip=dhcp \
    --mp0 /mnt/shared,mp=/mnt/shared \
    --unprivileged 0 \
    --features nesting=1

pct start 100
```

### Inside Container - Install Java 21
```bash
pct enter 100

apt update && apt install -y wget gnupg screen mcrcon imagemagick

# Adoptium Java 21
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg
echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" > /etc/apt/sources.list.d/adoptium.list
apt update && apt install -y temurin-21-jdk
```

### Setup Minecraft Server
```bash
useradd -r -m -d /opt/minecraft minecraft
mkdir -p /opt/minecraft
cd /opt/minecraft

# Download Fabric server (check https://fabricmc.net/use/server/ for latest)
wget https://meta.fabricmc.net/v2/versions/loader/1.21.4/0.18.4/0.11.2/server/jar -O fabric-server.jar

# Copy config files from repo:
# - server.properties
# - start.sh (chmod +x)
# - backup.sh (chmod +x)
# - render_map.sh (chmod +x)
# - whitelist.json
# - ops.json

chown -R minecraft:minecraft /opt/minecraft
```

### Install unmined (map renderer)
```bash
cd /opt/minecraft
wget "https://unmined.net/download/unmined-cli-linux-x64-dev/" -O unmined-cli.tar.gz
tar -xzf unmined-cli.tar.gz
```

### Setup Systemd Service
Copy `minecraft/minecraft.service` to `/etc/systemd/system/minecraft.service`:
```bash
systemctl daemon-reload
systemctl enable minecraft
systemctl start minecraft
```

### Setup Cron Jobs
Copy cron files to `/etc/cron.d/`:
- `minecraft/cron-backup` -> `/etc/cron.d/minecraft-backup`
- `minecraft/cron-render-map` -> `/etc/cron.d/render-map`

## 3. Web Server Container (101)

### Create Container
```bash
pct create 101 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
    --hostname webserver \
    --memory 2048 \
    --cores 2 \
    --rootfs local-lvm:20 \
    --net0 name=eth0,bridge=vmbr0,firewall=0,ip=dhcp \
    --mp0 /mnt/shared,mp=/mnt/shared \
    --unprivileged 0

pct start 101
```

### Inside Container - Install Packages
```bash
pct enter 101

apt update
apt install -y python3 python3-pip python3-venv caddy openssh-client

# Create webapp user
useradd -r -m -d /opt/webapp webapp
mkdir -p /opt/webapp/static
```

### Setup Flask App
```bash
cd /opt/webapp
python3 -m venv venv
source venv/bin/activate
pip install flask gunicorn

# Copy app.py from repo
# Copy jee.bz.png to /opt/webapp/static/

chown -R webapp:webapp /opt/webapp
```

### Setup Caddy
Copy `webapp/Caddyfile` to `/etc/caddy/Caddyfile`:
```bash
systemctl restart caddy
```

### Setup Systemd Service
Copy `webapp/webapp.service` to `/etc/systemd/system/webapp.service`:
```bash
systemctl daemon-reload
systemctl enable webapp
systemctl start webapp
```

### Setup SSH for Map Rendering
```bash
mkdir -p /opt/webapp/.ssh
ssh-keygen -t ed25519 -f /opt/webapp/.ssh/id_ed25519 -N ""
chown -R webapp:webapp /opt/webapp/.ssh
chmod 700 /opt/webapp/.ssh
chmod 600 /opt/webapp/.ssh/id_ed25519

# Add public key to Proxmox host's /root/.ssh/authorized_keys
cat /opt/webapp/.ssh/id_ed25519.pub
```

## 4. Router Configuration

Configure port forwarding on your router:
- 22 (or custom SSH port) -> Proxmox host
- 25565 -> 192.168.0.165 (Minecraft container)
- 80 -> 192.168.0.105 (Web container)
- 443 -> 192.168.0.105 (Web container)

Setup static DHCP bindings:
- Minecraft container MAC -> 192.168.0.165
- Web container MAC -> 192.168.0.105

## 5. Restore World Data

If you have a backup of the Minecraft world:
```bash
# On Proxmox host
pct exec 100 -- systemctl stop minecraft
# Copy world folder to /opt/minecraft/world
pct exec 100 -- chown -R minecraft:minecraft /opt/minecraft/world
pct exec 100 -- systemctl start minecraft
```

## File Inventory

```
.
├── CLAUDE.md              # Project documentation
├── SETUP.md               # This file
├── connect.sh             # SSH connection helper
├── jee.bz.png             # Site logo
├── minecraft/
│   ├── server.properties  # MC server config
│   ├── start.sh           # JVM startup script
│   ├── backup.sh          # Daily backup script
│   ├── render_map.sh      # Map renderer with overlays
│   ├── minecraft.service  # Systemd unit
│   ├── whitelist.json     # Whitelisted players
│   ├── ops.json           # Server operators
│   ├── cron-backup        # Backup cron job
│   └── cron-render-map    # Map render cron job
├── webapp/
│   ├── app.py             # Flask application
│   ├── Caddyfile          # Caddy reverse proxy config
│   └── webapp.service     # Systemd unit
└── proxmox-host/
    ├── iptables-rules.v4  # NAT/forwarding rules
    ├── jail.local         # fail2ban config
    ├── lxc-100.conf       # MC container config
    └── lxc-101.conf       # Web container config
```
