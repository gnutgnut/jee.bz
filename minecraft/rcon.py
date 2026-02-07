#!/usr/bin/env python3
# Simple RCON client for Minecraft
# Usage: rcon.py <command>
# Password is read from server.properties

import socket, struct, sys, os

def get_password():
    props_file = "/opt/minecraft/server.properties"
    if os.path.exists(props_file):
        with open(props_file) as f:
            for line in f:
                if line.startswith("rcon.password="):
                    return line.split("=", 1)[1].strip()
    return os.environ.get("RCON_PASSWORD", "")

def rcon(host, port, password, command):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((host, port))

    def send(pkt_type, payload):
        pkt_id = 0
        data = struct.pack("<ii", pkt_id, pkt_type) + payload.encode() + b"\x00\x00"
        sock.send(struct.pack("<i", len(data)) + data)

    def recv():
        length = struct.unpack("<i", sock.recv(4))[0]
        data = sock.recv(length)
        return data[8:-2].decode()

    send(3, password)  # auth
    recv()
    send(2, command)   # command
    result = recv()
    sock.close()
    return result

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: rcon.py <command>")
        sys.exit(1)
    cmd = " ".join(sys.argv[1:])
    password = get_password()
    if not password:
        print("Error: Could not find RCON password")
        sys.exit(1)
    print(rcon("127.0.0.1", 25575, password, cmd))
