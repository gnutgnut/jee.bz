#!/bin/bash
# Switch between Minecraft server containers
# Run this ON the Proxmox host (or via ./connect.sh)
#
# Usage:
#   switch-mc.sh fabric    # Switch to Fabric (container 100)
#   switch-mc.sh spigot    # Switch to Spigot (container 103)
#   switch-mc.sh status    # Show which is currently running
#
# What it does:
#   1. Stops the currently running MC container
#   2. Updates iptables DNAT rule for port 25565
#   3. Starts the target container
#   4. Updates onboot flags so the right one starts on reboot

set -e

FABRIC_CTID=100
SPIGOT_CTID=103
MC_PORT=25565
BEDROCK_PORT=19132  # GeyserMC Bedrock port (UDP)

# Container IPs (set these after DHCP binding is configured)
FABRIC_IP="192.168.0.165"
SPIGOT_IP="192.168.0.166"  # TODO: Update after setting static DHCP

get_status() {
    local fabric_running=false
    local spigot_running=false

    if pct status $FABRIC_CTID 2>/dev/null | grep -q "running"; then
        fabric_running=true
    fi
    if pct status $SPIGOT_CTID 2>/dev/null | grep -q "running"; then
        spigot_running=true
    fi

    if $fabric_running && ! $spigot_running; then
        echo "fabric"
    elif $spigot_running && ! $fabric_running; then
        echo "spigot"
    elif $fabric_running && $spigot_running; then
        echo "both"  # shouldn't happen
    else
        echo "none"
    fi
}

update_iptables() {
    local target_ip=$1
    local is_spigot=$2  # "spigot" or "fabric"

    # Remove existing MC DNAT rules (Java TCP)
    while iptables -t nat -D PREROUTING ! -s 192.168.0.0/24 -p tcp --dport $MC_PORT -j DNAT --to-destination ${FABRIC_IP}:${MC_PORT} 2>/dev/null; do :; done
    while iptables -t nat -D PREROUTING ! -s 192.168.0.0/24 -p tcp --dport $MC_PORT -j DNAT --to-destination ${SPIGOT_IP}:${MC_PORT} 2>/dev/null; do :; done

    # Remove existing MC MASQUERADE rules (Java TCP)
    while iptables -t nat -D POSTROUTING -d ${FABRIC_IP}/32 -p tcp --dport $MC_PORT -j MASQUERADE 2>/dev/null; do :; done
    while iptables -t nat -D POSTROUTING -d ${SPIGOT_IP}/32 -p tcp --dport $MC_PORT -j MASQUERADE 2>/dev/null; do :; done

    # Remove existing Bedrock DNAT/MASQUERADE rules (UDP)
    while iptables -t nat -D PREROUTING ! -s 192.168.0.0/24 -p udp --dport $BEDROCK_PORT -j DNAT --to-destination ${SPIGOT_IP}:${BEDROCK_PORT} 2>/dev/null; do :; done
    while iptables -t nat -D POSTROUTING -d ${SPIGOT_IP}/32 -p udp --dport $BEDROCK_PORT -j MASQUERADE 2>/dev/null; do :; done

    # Add Java TCP rules pointing to target
    iptables -t nat -A PREROUTING ! -s 192.168.0.0/24 -p tcp --dport $MC_PORT -j DNAT --to-destination ${target_ip}:${MC_PORT}
    iptables -t nat -A POSTROUTING -d ${target_ip}/32 -p tcp --dport $MC_PORT -j MASQUERADE

    echo "iptables updated: port $MC_PORT/tcp -> $target_ip"

    # Add Bedrock UDP rules only when switching to Spigot (GeyserMC)
    if [ "$is_spigot" = "spigot" ]; then
        iptables -t nat -A PREROUTING ! -s 192.168.0.0/24 -p udp --dport $BEDROCK_PORT -j DNAT --to-destination ${target_ip}:${BEDROCK_PORT}
        iptables -t nat -A POSTROUTING -d ${target_ip}/32 -p udp --dport $BEDROCK_PORT -j MASQUERADE
        echo "iptables updated: port $BEDROCK_PORT/udp -> $target_ip (Bedrock/GeyserMC)"
    fi

    # Persist rules
    iptables-save > /etc/iptables/rules.v4
}

stop_container() {
    local ctid=$1
    local name=$2

    if pct status $ctid 2>/dev/null | grep -q "running"; then
        echo "Stopping $name (CT $ctid)..."
        # Graceful stop: tell MC to save and stop
        pct exec $ctid -- systemctl stop minecraft 2>/dev/null || true
        sleep 5
        pct shutdown $ctid --timeout 30 2>/dev/null || pct stop $ctid
        echo "$name stopped."
    else
        echo "$name already stopped."
    fi
}

start_container() {
    local ctid=$1
    local name=$2

    echo "Starting $name (CT $ctid)..."
    pct start $ctid

    # Wait for container
    for i in {1..30}; do
        if pct exec $ctid -- echo "ready" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    # Start minecraft service
    pct exec $ctid -- systemctl start minecraft
    echo "$name started."
}

set_onboot() {
    local active_ctid=$1
    local inactive_ctid=$2

    pct set $active_ctid --onboot 1
    pct set $inactive_ctid --onboot 0
    echo "onboot: CT $active_ctid=on, CT $inactive_ctid=off"
}

case "${1:-status}" in
    fabric)
        current=$(get_status)
        if [ "$current" = "fabric" ]; then
            echo "Fabric is already running."
            exit 0
        fi

        echo "=== Switching to Fabric (CT $FABRIC_CTID) ==="
        stop_container $SPIGOT_CTID "Spigot"
        update_iptables $FABRIC_IP "fabric"
        start_container $FABRIC_CTID "Fabric"
        set_onboot $FABRIC_CTID $SPIGOT_CTID
        echo ""
        echo "Done! Fabric server is now active on jee.bz:25565"
        ;;

    spigot)
        current=$(get_status)
        if [ "$current" = "spigot" ]; then
            echo "Spigot is already running."
            exit 0
        fi

        echo "=== Switching to Spigot (CT $SPIGOT_CTID) ==="
        stop_container $FABRIC_CTID "Fabric"
        update_iptables $SPIGOT_IP "spigot"
        start_container $SPIGOT_CTID "Spigot"
        set_onboot $SPIGOT_CTID $FABRIC_CTID
        echo ""
        echo "Done! Spigot server is now active on jee.bz:25565 (Bedrock on :19132)"
        ;;

    status)
        current=$(get_status)
        echo "=== Minecraft Server Status ==="
        echo ""

        case "$current" in
            fabric)
                echo "Active: Fabric (CT $FABRIC_CTID) @ $FABRIC_IP"
                echo "Inactive: Spigot (CT $SPIGOT_CTID)"
                ;;
            spigot)
                echo "Active: Spigot (CT $SPIGOT_CTID) @ $SPIGOT_IP"
                echo "Inactive: Fabric (CT $FABRIC_CTID)"
                ;;
            both)
                echo "WARNING: Both containers are running!"
                echo "  Fabric (CT $FABRIC_CTID): running"
                echo "  Spigot (CT $SPIGOT_CTID): running"
                echo ""
                echo "Run 'switch-mc.sh fabric' or 'switch-mc.sh spigot' to fix."
                ;;
            none)
                echo "No Minecraft server is running."
                echo ""
                echo "Run 'switch-mc.sh fabric' or 'switch-mc.sh spigot' to start one."
                ;;
        esac
        ;;

    *)
        echo "Usage: switch-mc.sh {fabric|spigot|status}"
        echo ""
        echo "  fabric  - Switch to Fabric server (CT $FABRIC_CTID)"
        echo "  spigot  - Switch to Spigot server (CT $SPIGOT_CTID)"
        echo "  status  - Show which server is currently running"
        exit 1
        ;;
esac
