#!/bin/bash
# Render high-quality cinematic background image
# Runs at low priority, atmospheric washed-out style
# Uses current isometric camera position

OUTPUT="/mnt/shared/site_background.jpg"
TEMP="/tmp/background_render.png"
SCENE_DIR="/opt/chunky/scenes"
SCENE_NAME="background_cinematic"
STATE_FILE="/opt/chunky/camera_state"
LOCK_FILE="/tmp/background_render.lock"

# Only one instance at a time
exec 200>"$LOCK_FILE"
flock -n 200 || { echo "Background render already running"; exit 0; }

# Load camera state (same as isometric view)
if [ -f "$STATE_FILE" ]; then
    source "$STATE_FILE"
else
    CAM_X=-29
    CAM_Z=415
    FOV=80
fi

# Clear old scene data
rm -f "${SCENE_DIR}/${SCENE_NAME}"* 2>/dev/null

# Larger range for background (wider view)
RANGE=$(( FOV * 300 / 80 ))
CHUNK_X_MIN=$(( (CAM_X - RANGE) / 16 ))
CHUNK_X_MAX=$(( (CAM_X + RANGE) / 16 ))
CHUNK_Z_MIN=$(( (CAM_Z - RANGE) / 16 ))
CHUNK_Z_MAX=$(( (CAM_Z + RANGE) / 16 ))

# Generate chunk list
CHUNKS=""
for cx in $(seq $CHUNK_X_MIN $CHUNK_X_MAX); do
    for cz in $(seq $CHUNK_Z_MIN $CHUNK_Z_MAX); do
        CHUNKS="${CHUNKS}[${cx},${cz}],"
    done
done
CHUNKS="${CHUNKS%,}"

# Create cinematic scene - higher quality, atmospheric settings
cat > "${SCENE_DIR}/${SCENE_NAME}.json" << EOF
{
  "sdfVersion": 9,
  "name": "${SCENE_NAME}",
  "width": 1920,
  "height": 1080,
  "exposure": 0.8,
  "postprocess": "GAMMA",
  "outputMode": "PNG",
  "renderTime": 0,
  "spp": 0,
  "sppTarget": 64,
  "dumpFrequency": 100,
  "saveSnapshots": false,
  "rayDepth": 5,
  "pathTrace": true,
  "emittersEnabled": true,
  "emitterIntensity": 10.0,
  "stillWater": true,
  "waterOpacity": 0.6,
  "waterVisibility": 12.0,
  "useCustomWaterColor": false,
  "biomeColorsEnabled": true,
  "fastFog": false,
  "fogDensity": 0.02,
  "transparentSky": false,
  "renderActors": true,
  "octreeImplementation": "PACKED",
  "bvhImplementation": "SAH_MA",
  "emitterSamplingStrategy": "NONE",
  "sun": {
    "altitude": 0.8,
    "azimuth": 2.0,
    "intensity": 1.0,
    "color": {
      "red": 1.0,
      "green": 0.95,
      "blue": 0.85
    },
    "drawTexture": true
  },
  "sky": {
    "mode": "SIMULATED",
    "skyLight": 0.8,
    "skyYaw": 0.0,
    "skyMirrored": true,
    "cloudsEnabled": true,
    "cloudSize": 128.0,
    "cloudOffset": {
      "x": 0.0,
      "y": 128.0,
      "z": 0.0
    }
  },
  "camera": {
    "name": "cinematic",
    "position": {
      "x": ${CAM_X}.0,
      "y": 140.0,
      "z": ${CAM_Z}.0
    },
    "orientation": {
      "roll": 0.0,
      "pitch": -0.45,
      "yaw": -2.356194490192345
    },
    "projectionMode": "PARALLEL",
    "fov": $((FOV + 20)).0,
    "dof": "Infinity",
    "focalOffset": 2.0,
    "shift": {
      "x": 0.0,
      "y": 0.0
    }
  },
  "world": {
    "path": "/opt/minecraft/world",
    "dimension": 0
  },
  "chunkList": [${CHUNKS}],
  "entities": [],
  "actors": [],
  "materials": {},
  "cameraPresets": []
}
EOF

echo "$(date): Starting cinematic background render (cam: $CAM_X,$CAM_Z)..."

# Run Chunky at low priority
cd /opt/chunky
nice -n 19 java -Dchunky.home=/opt/chunky \
     -jar ChunkyLauncher.jar \
     -scene-dir "$SCENE_DIR" \
     -render "$SCENE_NAME" \
     -target 64 \
     -threads 4 \
     -f \
     2>&1 | grep -E "(Rendering|SPP|error)" | tail -5

# Take snapshot
java -Dchunky.home=/opt/chunky \
     -jar ChunkyLauncher.jar \
     -scene-dir "$SCENE_DIR" \
     -snapshot "$SCENE_NAME" "$TEMP" \
     2>/dev/null

if [ -f "$TEMP" ] && [ $(stat -c%s "$TEMP" 2>/dev/null || echo 0) -gt 50000 ]; then
    # Post-process: just vignette and JPEG conversion
    convert "$TEMP" \
        \( +clone -fill black -colorize 100% -fill white -draw "ellipse 960,540 1200,800 0,360" -blur 0x40 \) \
        -compose multiply -composite \
        -quality 90 \
        "$OUTPUT"

    rm -f "$TEMP"
    echo "$(date): Cinematic background render complete"

    # Signal webapp to refresh (touch a marker file)
    touch /mnt/shared/.background_updated
else
    echo "$(date): Background render failed"
fi
