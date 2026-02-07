import subprocess
from flask import Flask, render_template_string, jsonify, send_from_directory
import socket
import struct
import json
import os

app = Flask(__name__)

MC_HOST = "192.168.0.165"
MC_PORT = 25565

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>jee.bz</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" type="image/png" href="/static/favicon.png">
    <link href="https://fonts.googleapis.com/css2?family=Press+Start+2P&family=Inter:wght@400;600&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        
        body {
            font-family: "Inter", sans-serif;
            background: #0a0a0f;
            color: #e0e0e0;
            min-height: 100vh;
            overflow-x: hidden;
        }

        .bg-cinematic {
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: linear-gradient(rgba(5, 5, 10, 0.25), rgba(5, 5, 10, 0.35)), url('/static/site_background.jpg');
            background-size: cover;
            background-position: center;
            z-index: 0;
            transition: opacity 1s ease-in-out;
        }

        .bg-cinematic.loading {
            opacity: 0;
        }

        .bg-cinematic.peek {
            background: url('/static/site_background.jpg');
            background-size: cover;
            background-position: center;
            z-index: 9999;
            cursor: grabbing;
        }
        
        .bg-grid {
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background-image:
                linear-gradient(rgba(34, 197, 94, 0.03) 1px, transparent 1px),
                linear-gradient(90deg, rgba(34, 197, 94, 0.03) 1px, transparent 1px);
            background-size: 50px 50px;
            animation: gridMove 20s linear infinite;
            z-index: 1;
            pointer-events: none;
        }
        
        @keyframes gridMove {
            0% { transform: translate(0, 0); }
            100% { transform: translate(50px, 50px); }
        }
        
        .container { 
            position: relative;
            z-index: 1;
            max-width: 600px; 
            margin: 0 auto; 
            padding: 40px 20px;
        }
        
        .logo {
            display: block;
            max-width: 300px;
            margin: 0 auto 40px auto;
        }
        
        h1 { 
            font-family: "Press Start 2P", monospace;
            font-size: 2.5em;
            text-align: center;
            margin-bottom: 40px;
            background: linear-gradient(135deg, #22c55e 0%, #16a34a 50%, #22c55e 100%);
            background-size: 200% auto;
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            animation: shine 3s linear infinite;
            text-shadow: 0 0 40px rgba(34, 197, 94, 0.3);
        }
        
        @keyframes shine {
            0% { background-position: 0% center; }
            100% { background-position: 200% center; }
        }
        
        .card {
            background: linear-gradient(135deg, rgba(20, 20, 30, 0.9) 0%, rgba(15, 15, 20, 0.95) 100%);
            border: 1px solid rgba(34, 197, 94, 0.2);
            border-radius: 16px;
            padding: 30px;
            backdrop-filter: blur(10px);
            box-shadow: 
                0 0 0 1px rgba(34, 197, 94, 0.1),
                0 20px 50px rgba(0, 0, 0, 0.5),
                inset 0 1px 0 rgba(255, 255, 255, 0.05);
            margin-bottom: 20px;
        }
        
        .card:hover {
            border-color: rgba(34, 197, 94, 0.4);
            box-shadow: 
                0 0 0 1px rgba(34, 197, 94, 0.2),
                0 20px 50px rgba(0, 0, 0, 0.5),
                0 0 30px rgba(34, 197, 94, 0.1),
                inset 0 1px 0 rgba(255, 255, 255, 0.05);
        }
        
        .server-header {
            display: flex;
            align-items: center;
            gap: 15px;
            margin-bottom: 25px;
            padding-bottom: 20px;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        
        .server-icon {
            width: 64px;
            height: 64px;
            background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 28px;
            box-shadow: 0 4px 15px rgba(34, 197, 94, 0.3);
        }
        
        .server-title h2 {
            font-family: "Press Start 2P", monospace;
            font-size: 0.9em;
            color: #fff;
            margin-bottom: 5px;
        }
        
        .server-title .motd {
            font-size: 0.85em;
            color: #22c55e;
        }
        
        .status-bar {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 25px;
        }
        
        .status-indicator {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 16px;
            border-radius: 100px;
            font-weight: 600;
            font-size: 0.85em;
            transition: all 0.3s ease;
        }
        
        .status-indicator.online {
            background: rgba(34, 197, 94, 0.15);
            color: #22c55e;
            border: 1px solid rgba(34, 197, 94, 0.3);
        }
        
        .status-indicator.offline {
            background: rgba(239, 68, 68, 0.15);
            color: #ef4444;
            border: 1px solid rgba(239, 68, 68, 0.3);
        }
        
        .dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            transition: all 0.3s ease;
        }
        
        .dot.online {
            background: #22c55e;
            box-shadow: 0 0 10px #22c55e;
            animation: pulse 2s ease-in-out infinite;
        }
        
        .dot.offline {
            background: #ef4444;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.6; transform: scale(1.1); }
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 15px;
            margin-bottom: 25px;
        }
        
        .stat-box {
            background: rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.05);
            border-radius: 10px;
            padding: 15px;
            text-align: center;
        }
        
        .stat-box .value {
            font-family: "Press Start 2P", monospace;
            font-size: 1.2em;
            color: #22c55e;
            margin-bottom: 5px;
            transition: all 0.3s ease;
        }
        
        .stat-box .label {
            font-size: 0.75em;
            color: #888;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .stat-box .value.updating {
            opacity: 0.5;
        }
        
        .connect-box {
            background: linear-gradient(135deg, rgba(34, 197, 94, 0.1) 0%, rgba(34, 197, 94, 0.05) 100%);
            border: 1px dashed rgba(34, 197, 94, 0.3);
            border-radius: 10px;
            padding: 20px;
            text-align: center;
            margin-bottom: 20px;
        }
        
        .connect-box .label {
            font-size: 0.75em;
            color: #888;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 8px;
        }
        
        .connect-box .address {
            font-family: "Press Start 2P", monospace;
            font-size: 1.1em;
            color: #22c55e;
            cursor: pointer;
            transition: all 0.2s;
        }
        
        .connect-box .address:hover {
            color: #4ade80;
            text-shadow: 0 0 20px rgba(34, 197, 94, 0.5);
        }
        
        .footer {
            text-align: center;
            font-size: 0.8em;
            color: #666;
        }
        
        .footer a {
            color: #22c55e;
            text-decoration: none;
            transition: color 0.2s;
        }
        
        .footer a:hover {
            color: #4ade80;
        }
        
        /* Map section */
        .map-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        
        .map-header h3 {
            font-family: "Press Start 2P", monospace;
            font-size: 0.8em;
            color: #fff;
        }
        
        .map-header .update-info {
            font-size: 0.7em;
            color: #666;
        }

        .refresh-btn {
            background: rgba(34, 197, 94, 0.15);
            border: 1px solid rgba(34, 197, 94, 0.3);
            color: #22c55e;
            padding: 6px 12px;
            border-radius: 6px;
            font-size: 0.7em;
            cursor: pointer;
            transition: all 0.2s;
        }

        .refresh-btn:hover {
            background: rgba(34, 197, 94, 0.25);
            border-color: rgba(34, 197, 94, 0.5);
        }

        .refresh-btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }

        .refresh-btn.loading {
            animation: btnPulse 1s ease-in-out infinite;
        }

        @keyframes btnPulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        .map-container {
            text-align: center;
            position: relative;
        }
        
        .map-container img {
            max-width: 100%;
            border-radius: 10px;
            border: 1px solid rgba(34, 197, 94, 0.2);
            image-rendering: pixelated;
            image-rendering: crisp-edges;
        }
        
        .map-legend {
            display: flex;
            justify-content: center;
            gap: 20px;
            margin-top: 15px;
            font-size: 0.75em;
            color: #888;
        }
        
        .legend-item {
            display: flex;
            align-items: center;
            gap: 6px;
        }
        
        .legend-color {
            width: 12px;
            height: 12px;
            border-radius: 3px;
        }
        
        .spawn-marker { background: #ff0000; }
        .grass-color { background: #7cbd6b; }
        .water-color { background: #4040ff; }
        .stone-color { background: #7d7d7d; }
        
        .live-badge {
            display: inline-flex;
            align-items: center;
            gap: 5px;
            font-size: 0.65em;
            color: #888;
            margin-left: auto;
            padding: 4px 8px;
            background: rgba(0,0,0,0.3);
            border-radius: 4px;
        }
        
        .live-dot {
            width: 6px;
            height: 6px;
            background: #22c55e;
            border-radius: 50%;
            animation: livePulse 1.5s ease-in-out infinite;
        }
        
        @keyframes livePulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.3; }
        }

        /* Camera controls */
        .camera-panel {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 20px;
            margin-top: 15px;
            padding-top: 15px;
            border-top: 1px solid rgba(255,255,255,0.1);
        }

        .camera-controls {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 5px;
        }

        .cam-stats {
            font-family: "Press Start 2P", monospace;
            font-size: 8px;
            color: #666;
            line-height: 1.8;
            text-align: right;
        }

        .cam-stats div {
            transition: color 0.3s;
        }

        .cam-stats.updating div {
            color: #22c55e;
        }

        .control-row {
            display: flex;
            gap: 5px;
            align-items: center;
        }

        .cam-btn {
            width: 36px;
            height: 36px;
            background: rgba(34, 197, 94, 0.15);
            border: 1px solid rgba(34, 197, 94, 0.3);
            color: #22c55e;
            border-radius: 6px;
            font-size: 16px;
            cursor: pointer;
            transition: all 0.2s;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .cam-btn:hover {
            background: rgba(34, 197, 94, 0.25);
            border-color: rgba(34, 197, 94, 0.5);
            transform: scale(1.05);
        }

        .cam-btn:active {
            transform: scale(0.95);
        }

        .cam-btn:disabled {
            opacity: 0.4;
            cursor: not-allowed;
            transform: none;
        }

        .cam-btn.loading {
            animation: btnPulse 1s ease-in-out infinite;
        }

        .zoom-btn {
            font-size: 20px;
            font-weight: bold;
        }

        .reset-btn {
            font-size: 18px;
        }
    </style>
</head>
<body>
    <div class="bg-cinematic" id="bg-cinematic"></div>
    <div class="bg-grid"></div>
    <div class="container">
        <img src="/static/jee.bz.png" alt="JEE.BZ" class="logo">
        
        <div class="card">
            <div class="server-header">
                <div class="server-icon">⛏</div>
                <div class="server-title">
                    <h2>Minecraft</h2>
                    <div class="motd" id="motd">{{ mc.motd if mc.online else '' }}</div>
                </div>
                <div class="live-badge"><span class="live-dot"></span>LIVE</div>
            </div>
            
            <div class="status-bar">
                <div class="status-indicator" id="status-indicator">
                    <span class="dot" id="status-dot"></span>
                    <span id="status-text">{{ 'ONLINE' if mc.online else 'OFFLINE' }}</span>
                </div>
                <div class="status-indicator online" id="version-indicator" style="margin-left: auto; {{ '' if mc.online else 'display:none;' }}">
                    v<span id="version">{{ mc.version }}</span>
                </div>
            </div>
            
            <div class="stats-grid" id="stats-grid" style="{{ '' if mc.online else 'display:none;' }}">
                <div class="stat-box">
                    <div class="value" id="players-online">{{ mc.players_online }}</div>
                    <div class="label">Players Online</div>
                </div>
                <div class="stat-box">
                    <div class="value" id="players-max">{{ mc.players_max }}</div>
                    <div class="label">Max Players</div>
                </div>
            </div>
            
            <div class="connect-box">
                <div class="label">Server Address</div>
                <div class="address" onclick="navigator.clipboard.writeText('jee.bz'); this.textContent='Copied!'; setTimeout(() => this.textContent='jee.bz', 1500)">jee.bz</div>
            </div>
            
            <div class="footer">
                Request access: <a href="mailto:mc@flyingspark.eu">mc@flyingspark.eu</a>
                <span style="margin-left: 15px;"><a href="/map/" style="color: #22c55e;">3D Map</a></span>
                <span style="margin-left: 15px;"><a href="https://status.jee.bz" style="color: #22c55e;">Status</a></span>
                <span style="margin-left: 15px; opacity: 0.3;"><a href="https://github.com/gnutgnut/jee.bz" style="color: #666;">src</a></span>
            </div>
        </div>
        
        {% if map_exists %}
        <div class="card">
            <div class="map-header">
                <h3>Spawn Area Map</h3>
                <button class="refresh-btn" id="refresh-map-btn" onclick="refreshMap()">Refresh</button>
            </div>
            <div class="map-container">
                <img id="spawn-map-img" src="/static/spawn_map.png?v={{ cache_bust }}" alt="Spawn Area Map" title="512x512 blocks around spawn">
            </div>
            <div class="map-legend">
                <div class="legend-item"><span class="legend-color spawn-marker"></span> Spawn</div>
                <div class="legend-item"><span class="legend-color grass-color"></span> Grass</div>
                <div class="legend-item"><span class="legend-color water-color"></span> Water</div>
                <div class="legend-item"><span class="legend-color stone-color"></span> Stone</div>
            </div>
        </div>
        {% endif %}

        {% if detail_exists %}
        <div class="card">
            <div class="map-header">
                <h3>Isometric 3D View</h3>
                <button class="refresh-btn" id="refresh-detail-btn" onclick="refreshDetail()">Refresh</button>
            </div>
            <div class="map-container">
                <img id="detail-map-img" src="/static/spawn_detail.png?v={{ cache_bust_detail }}" alt="Isometric 3D View" title="Chunky path-traced render">
            </div>
            <div class="camera-panel">
                <div class="camera-controls">
                    <div class="control-row">
                        <button class="cam-btn" onclick="moveCamera('n')" title="Move North">&#9650;</button>
                    </div>
                    <div class="control-row">
                        <button class="cam-btn" onclick="moveCamera('w')" title="Move West">&#9664;</button>
                        <button class="cam-btn zoom-btn" onclick="moveCamera('in')" title="Zoom In">+</button>
                        <button class="cam-btn zoom-btn" onclick="moveCamera('out')" title="Zoom Out">−</button>
                        <button class="cam-btn" onclick="moveCamera('e')" title="Move East">&#9654;</button>
                    </div>
                    <div class="control-row">
                        <button class="cam-btn" onclick="moveCamera('s')" title="Move South">&#9660;</button>
                    </div>
                    <div class="control-row">
                        <button class="cam-btn reset-btn" onclick="moveCamera('reset')" title="Reset Camera">&#8634;</button>
                    </div>
                </div>
                <div class="cam-stats" id="cam-stats">
                    <div id="cam-x">---</div>
                    <div id="cam-z">---</div>
                    <div id="cam-fov">--</div>
                </div>
            </div>
        </div>
        {% endif %}
    </div>
    
    <script>
        let lastOnline = {{ 'true' if mc.online else 'false' }};
        
        async function updateStatus() {
            try {
                const response = await fetch('/api/mc');
                const data = await response.json();
                
                const statusIndicator = document.getElementById('status-indicator');
                const statusDot = document.getElementById('status-dot');
                const statusText = document.getElementById('status-text');
                const versionIndicator = document.getElementById('version-indicator');
                const version = document.getElementById('version');
                const statsGrid = document.getElementById('stats-grid');
                const playersOnline = document.getElementById('players-online');
                const playersMax = document.getElementById('players-max');
                const motd = document.getElementById('motd');
                
                if (data.online) {
                    statusIndicator.className = 'status-indicator online';
                    statusDot.className = 'dot online';
                    statusText.textContent = 'ONLINE';
                    versionIndicator.style.display = '';
                    version.textContent = data.version;
                    statsGrid.style.display = '';
                    playersOnline.textContent = data.players_online;
                    playersMax.textContent = data.players_max;
                    motd.textContent = data.motd;
                } else {
                    statusIndicator.className = 'status-indicator offline';
                    statusDot.className = 'dot offline';
                    statusText.textContent = 'OFFLINE';
                    versionIndicator.style.display = 'none';
                    statsGrid.style.display = 'none';
                    motd.textContent = '';
                }
                
                lastOnline = data.online;
            } catch (e) {
                console.error('Failed to fetch status:', e);
            }
        }
        
        // Update every 10 seconds
        setInterval(updateStatus, 10000);

        async function refreshMap() {
            const btn = document.getElementById('refresh-map-btn');
            const mapImg = document.getElementById('spawn-map-img');

            btn.disabled = true;
            btn.classList.add('loading');
            btn.textContent = 'Rendering...';

            try {
                const response = await fetch('/api/render-map', { method: 'POST' });
                const data = await response.json();

                if (data.success) {
                    mapImg.src = '/static/spawn_map.png?v=' + Date.now();
                    btn.textContent = 'Done!';
                    setTimeout(() => { btn.textContent = 'Refresh'; }, 2000);
                } else {
                    btn.textContent = 'Failed';
                    setTimeout(() => { btn.textContent = 'Refresh'; }, 2000);
                }
            } catch (e) {
                console.error('Failed to refresh map:', e);
                btn.textContent = 'Error';
                setTimeout(() => { btn.textContent = 'Refresh'; }, 2000);
            }

            btn.disabled = false;
            btn.classList.remove('loading');
        }

        async function refreshDetail() {
            const btn = document.getElementById('refresh-detail-btn');
            const detailImg = document.getElementById('detail-map-img');
            const stats = document.getElementById('cam-stats');

            btn.disabled = true;
            btn.classList.add('loading');
            btn.textContent = 'Rendering...';
            if (stats) stats.classList.add('updating');

            try {
                const response = await fetch('/api/render-detail', { method: 'POST' });
                const data = await response.json();

                if (data.success) {
                    detailImg.src = '/static/spawn_detail.png?v=' + Date.now();
                    if (data.cam) updateCamStats(data.cam);
                    btn.textContent = 'Done!';
                    setTimeout(() => { btn.textContent = 'Refresh'; }, 2000);
                } else {
                    btn.textContent = 'Failed';
                    setTimeout(() => { btn.textContent = 'Refresh'; }, 2000);
                }
            } catch (e) {
                console.error('Failed to refresh detail:', e);
                btn.textContent = 'Error';
                setTimeout(() => { btn.textContent = 'Refresh'; }, 2000);
            }

            btn.disabled = false;
            btn.classList.remove('loading');
            if (stats) stats.classList.remove('updating');
        }

        let renderTimeout = null;
        let pendingMoves = [];

        async function moveCamera(direction) {
            // Queue the move
            pendingMoves.push(direction);

            // Update stats immediately (optimistic)
            const cam = {
                x: parseInt(document.getElementById('cam-x').textContent) || -100,
                z: parseInt(document.getElementById('cam-z').textContent) || -270,
                fov: parseInt(document.getElementById('cam-fov').textContent) || 80
            };

            if (direction === 'n') cam.z -= 30;
            else if (direction === 's') cam.z += 30;
            else if (direction === 'e') cam.x += 30;
            else if (direction === 'w') cam.x -= 30;
            else if (direction === 'in') cam.fov = Math.max(30, cam.fov - 10);
            else if (direction === 'out') cam.fov = Math.min(150, cam.fov + 10);
            else if (direction === 'reset') { cam.x = -100; cam.z = -270; cam.fov = 80; }

            updateCamStats(cam);
            document.getElementById('cam-stats').classList.add('updating');

            // Clear previous timeout and set new one
            if (renderTimeout) clearTimeout(renderTimeout);
            renderTimeout = setTimeout(triggerRender, 1000);
        }

        async function triggerRender() {
            const btns = document.querySelectorAll('.cam-btn');
            const detailImg = document.getElementById('detail-map-img');
            const stats = document.getElementById('cam-stats');

            // Get all pending moves
            const moves = pendingMoves.join(',');
            pendingMoves = [];

            btns.forEach(b => { b.disabled = true; b.classList.add('loading'); });

            try {
                const response = await fetch('/api/render-detail?moves=' + moves, { method: 'POST' });
                const data = await response.json();

                if (data.success) {
                    detailImg.src = '/static/spawn_detail.png?v=' + Date.now();
                    if (data.cam) updateCamStats(data.cam);
                }
            } catch (e) {
                console.error('Failed to render:', e);
            }

            btns.forEach(b => { b.disabled = false; b.classList.remove('loading'); });
            if (stats) stats.classList.remove('updating');
        }

        function updateCamStats(cam) {
            document.getElementById('cam-x').textContent = cam.x;
            document.getElementById('cam-z').textContent = cam.z;
            document.getElementById('cam-fov').textContent = cam.fov;
        }

        // Load camera stats on page load
        fetch('/api/cam-stats').then(r => r.json()).then(updateCamStats).catch(() => {});

        // Check for background image updates
        let lastBgUpdate = 0;
        async function checkBackground() {
            try {
                const response = await fetch('/api/background-status');
                const data = await response.json();
                if (data.updated > lastBgUpdate && data.exists) {
                    lastBgUpdate = data.updated;
                    const bg = document.getElementById('bg-cinematic');
                    bg.classList.add('loading');
                    const img = new Image();
                    img.onload = () => {
                        bg.style.backgroundImage = 'url(/static/site_background.jpg?v=' + data.updated + ')';
                        setTimeout(() => bg.classList.remove('loading'), 100);
                    };
                    img.src = '/static/site_background.jpg?v=' + data.updated;
                }
            } catch (e) {}
        }
        checkBackground();
        setInterval(checkBackground, 30000);

        // Peek at background without filters on click-hold
        const bgEl = document.getElementById('bg-cinematic');
        bgEl.style.cursor = 'grab';
        bgEl.addEventListener('mousedown', () => bgEl.classList.add('peek'));
        bgEl.addEventListener('mouseup', () => bgEl.classList.remove('peek'));
        bgEl.addEventListener('mouseleave', () => bgEl.classList.remove('peek'));
        bgEl.addEventListener('touchstart', () => bgEl.classList.add('peek'));
        bgEl.addEventListener('touchend', () => bgEl.classList.remove('peek'));
    </script>
</body>
</html>
"""

def write_varint(val):
    result = b""
    while True:
        b = val & 0x7F
        val >>= 7
        if val:
            result += bytes([b | 0x80])
        else:
            result += bytes([b])
            break
    return result

def read_varint(sock):
    val = 0
    for i in range(5):
        b = sock.recv(1)
        if not b:
            raise Exception("No data")
        b = b[0]
        val |= (b & 0x7F) << (7 * i)
        if not (b & 0x80):
            break
    return val

def mc_status():
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect((MC_HOST, MC_PORT))
        
        host = MC_HOST.encode("utf-8")
        packet = write_varint(0)
        packet += write_varint(0)
        packet += write_varint(len(host)) + host
        packet += struct.pack(">H", MC_PORT)
        packet += write_varint(1)
        sock.send(write_varint(len(packet)) + packet)
        
        status_request = write_varint(0)
        sock.send(write_varint(len(status_request)) + status_request)
        
        length = read_varint(sock)
        packet_id = read_varint(sock)
        json_length = read_varint(sock)
        
        response = b""
        while len(response) < json_length:
            response += sock.recv(json_length - len(response))
        
        sock.close()
        data = json.loads(response.decode("utf-8"))
        
        motd = data.get("description", "")
        if isinstance(motd, dict):
            motd = motd.get("text", "")
        
        return {
            "online": True,
            "players_online": data.get("players", {}).get("online", 0),
            "players_max": data.get("players", {}).get("max", 0),
            "version": data.get("version", {}).get("name", "Unknown"),
            "motd": motd
        }
    except:
        return {"online": False, "players_online": 0, "players_max": 0, "version": "", "motd": ""}

@app.route("/")
def index():
    mc = mc_status()
    map_exists = os.path.exists("/opt/webapp/static/spawn_map.png")
    cache_bust = int(os.path.getmtime("/opt/webapp/static/spawn_map.png")) if map_exists else 0
    detail_exists = os.path.exists("/opt/webapp/static/spawn_detail.png")
    cache_bust_detail = int(os.path.getmtime("/opt/webapp/static/spawn_detail.png")) if detail_exists else 0
    return render_template_string(HTML_TEMPLATE, mc=mc, map_exists=map_exists, cache_bust=cache_bust, detail_exists=detail_exists, cache_bust_detail=cache_bust_detail)

@app.route("/static/<path:filename>")
def static_files(filename):
    return send_from_directory("/opt/webapp/static", filename)

@app.route("/api/render-map", methods=["POST"])
def render_map():
    try:
        cmd = 'pct exec 100 -- /opt/minecraft/render_map.sh'
        result = subprocess.run(["/bin/ssh", "-o", "StrictHostKeyChecking=no", "root@192.168.0.124", cmd], capture_output=True, timeout=90)
        if result.returncode != 0:
            return jsonify({"success": False, "message": f"SSH failed: {result.stderr.decode()[-500:]}"}), 500
        subprocess.run(["/bin/cp", "/mnt/shared/spawn_map.png", "/opt/webapp/static/"], timeout=10)
        return jsonify({"success": True, "message": "Map updated"})
    except subprocess.TimeoutExpired:
        return jsonify({"success": False, "message": "Render timed out"}), 500
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

@app.route("/api/render-detail", methods=["POST"])
def render_detail():
    from flask import request
    try:
        # Get camera movements (can be comma-separated for batched moves)
        moves = request.args.get('moves', '') or request.args.get('move', '')
        valid_moves = ['n', 's', 'e', 'w', 'in', 'out', 'reset']
        move_list = [m for m in moves.split(',') if m in valid_moves]

        if move_list:
            # Pass comma-separated moves to script (it handles them internally)
            move_str = ','.join(move_list)
            cmd = f'pct exec 100 -- /opt/minecraft/render_isometric.sh {move_str}'
        else:
            cmd = 'pct exec 100 -- /opt/minecraft/render_isometric.sh'
        result = subprocess.run(["/bin/ssh", "-o", "StrictHostKeyChecking=no", "root@192.168.0.124", cmd], capture_output=True, timeout=300)
        if result.returncode != 0:
            return jsonify({"success": False, "message": f"SSH failed: {result.stderr.decode()[-500:]}"}), 500
        subprocess.run(["/bin/cp", "/mnt/shared/spawn_detail.png", "/opt/webapp/static/"], timeout=10)
        # Read camera state
        cam = {"x": -100, "z": -270, "fov": 80}
        try:
            state = subprocess.run(["/bin/ssh", "-o", "StrictHostKeyChecking=no", "root@192.168.0.124",
                "pct exec 100 -- cat /opt/chunky/camera_state"], capture_output=True, timeout=10)
            for line in state.stdout.decode().split('\n'):
                if line.startswith('CAM_X='): cam['x'] = int(line.split('=')[1])
                elif line.startswith('CAM_Z='): cam['z'] = int(line.split('=')[1])
                elif line.startswith('FOV='): cam['fov'] = int(line.split('=')[1])
        except: pass
        return jsonify({"success": True, "message": "Detail updated", "cam": cam})
    except subprocess.TimeoutExpired:
        return jsonify({"success": False, "message": "Render timed out"}), 500
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

@app.route("/api/mc")
def api_mc():
    return jsonify(mc_status())

@app.route("/api/cam-stats")
def cam_stats():
    cam = {"x": -100, "z": -270, "fov": 80}
    try:
        result = subprocess.run(["/bin/ssh", "-o", "StrictHostKeyChecking=no", "root@192.168.0.124",
            "pct exec 100 -- cat /opt/chunky/camera_state"], capture_output=True, timeout=10)
        for line in result.stdout.decode().split('\n'):
            if line.startswith('CAM_X='): cam['x'] = int(line.split('=')[1])
            elif line.startswith('CAM_Z='): cam['z'] = int(line.split('=')[1])
            elif line.startswith('FOV='): cam['fov'] = int(line.split('=')[1])
    except: pass
    return jsonify(cam)

@app.route("/api/background-status")
def background_status():
    bg_path = "/opt/webapp/static/site_background.jpg"
    shared_path = "/mnt/shared/site_background.jpg"
    exists = os.path.exists(bg_path)
    updated = int(os.path.getmtime(bg_path)) if exists else 0
    # Check if shared has newer version and copy it
    if os.path.exists(shared_path):
        shared_time = int(os.path.getmtime(shared_path))
        if shared_time > updated:
            try:
                subprocess.run(["/bin/cp", shared_path, bg_path], timeout=10)
                updated = shared_time
                exists = True
            except: pass
    return jsonify({"exists": exists, "updated": updated})

@app.route("/api/render-background", methods=["POST"])
def render_background():
    try:
        # Run background render in background (non-blocking)
        cmd = 'pct exec 100 -- nohup /opt/minecraft/render_background.sh > /tmp/bg_render.log 2>&1 &'
        subprocess.run(["/bin/ssh", "-o", "StrictHostKeyChecking=no", "root@192.168.0.124", cmd], capture_output=True, timeout=10)
        return jsonify({"success": True, "message": "Background render started"})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
