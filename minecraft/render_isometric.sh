#!/bin/bash
# Render isometric 3D view of spawn area using Chunky
# Path-traced rendering for high quality output
# Usage: render_isometric.sh [n|s|e|w|in|out|reset]

OUTPUT="/mnt/shared/spawn_detail.png"
TEMP="/tmp/spawn_isometric.png"
LOGO="/mnt/shared/jee.bz.png"
LOGO_SMALL="/tmp/jee_logo_small_iso.png"
SCENE_DIR="/opt/chunky/scenes"
SCENE_NAME="spawn_isometric"
STATE_FILE="/opt/chunky/camera_state"

# Default camera position (looking at base at -29,415)
DEFAULT_CAM_X=-29
DEFAULT_CAM_Z=415
DEFAULT_FOV=80
MOVE_STEP=30

# Load or initialize camera state
if [ -f "$STATE_FILE" ]; then
    source "$STATE_FILE"
else
    CAM_X=$DEFAULT_CAM_X
    CAM_Z=$DEFAULT_CAM_Z
    FOV=$DEFAULT_FOV
fi

# Handle camera movement arguments (can be comma-separated like "n,n,e,w")
IFS=',' read -ra MOVES <<< "$1"
for move in "${MOVES[@]}"; do
    case "$move" in
        n)  CAM_Z=$((CAM_Z - MOVE_STEP)) ;;
        s)  CAM_Z=$((CAM_Z + MOVE_STEP)) ;;
        e)  CAM_X=$((CAM_X + MOVE_STEP)) ;;
        w)  CAM_X=$((CAM_X - MOVE_STEP)) ;;
        in) FOV=$((FOV - 10)); [ $FOV -lt 30 ] && FOV=30 ;;
        out) FOV=$((FOV + 10)); [ $FOV -gt 150 ] && FOV=150 ;;
        reset)
            CAM_X=$DEFAULT_CAM_X
            CAM_Z=$DEFAULT_CAM_Z
            FOV=$DEFAULT_FOV
            ;;
    esac
done

# Save camera state
cat > "$STATE_FILE" << EOF
CAM_X=$CAM_X
CAM_Z=$CAM_Z
FOV=$FOV
EOF

# Create scene directory if needed
mkdir -p "$SCENE_DIR"

# Clear ALL old scene data to force completely fresh render
rm -f "${SCENE_DIR}/${SCENE_NAME}"* 2>/dev/null
rm -rf "${SCENE_DIR}/snapshots" 2>/dev/null

# Calculate chunk range based on camera position and FOV
# Higher FOV = larger area rendered, lower FOV = smaller area
# Base range is 200 blocks at FOV 80, scales proportionally
RANGE=$(( FOV * 200 / 80 ))
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

# Create scene JSON with current camera position
cat > "${SCENE_DIR}/${SCENE_NAME}.json" << EOF
{
  "sdfVersion": 9,
  "name": "spawn_isometric",
  "width": 640,
  "height": 480,
  "exposure": 1.0,
  "postprocess": "GAMMA",
  "outputMode": "PNG",
  "renderTime": 0,
  "spp": 0,
  "sppTarget": 16,
  "dumpFrequency": 50,
  "saveSnapshots": false,
  "rayDepth": 3,
  "pathTrace": true,
  "emittersEnabled": true,
  "emitterIntensity": 13.0,
  "stillWater": false,
  "waterOpacity": 0.42,
  "waterVisibility": 9.0,
  "useCustomWaterColor": false,
  "biomeColorsEnabled": true,
  "fastFog": true,
  "fogDensity": 0.0,
  "transparentSky": false,
  "renderActors": true,
  "octreeImplementation": "PACKED",
  "bvhImplementation": "SAH_MA",
  "emitterSamplingStrategy": "NONE",
  "sun": {
    "altitude": 1.0471975511965976,
    "azimuth": 1.2566370614359172,
    "intensity": 1.25,
    "color": {
      "red": 1.0,
      "green": 1.0,
      "blue": 1.0
    },
    "drawTexture": true
  },
  "sky": {
    "mode": "SIMULATED",
    "skyLight": 1.0,
    "skyYaw": 0.0,
    "skyMirrored": true,
    "cloudsEnabled": false,
    "cloudSize": 64.0,
    "cloudOffset": {
      "x": 0.0,
      "y": 0.0,
      "z": 0.0
    }
  },
  "camera": {
    "name": "isometric",
    "position": {
      "x": ${CAM_X}.0,
      "y": 120.0,
      "z": ${CAM_Z}.0
    },
    "orientation": {
      "roll": 0.0,
      "pitch": -0.6154797086703874,
      "yaw": -2.356194490192345
    },
    "projectionMode": "PARALLEL",
    "fov": ${FOV}.0,
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

echo "Rendering isometric view (cam: $CAM_X,$CAM_Z fov: $FOV)..."

# Run Chunky in headless mode (-f forces render even without octree file)
cd /opt/chunky
java -Dchunky.home=/opt/chunky \
     -jar ChunkyLauncher.jar \
     -scene-dir "$SCENE_DIR" \
     -render "$SCENE_NAME" \
     -target 16 \
     -threads 6 \
     -f \
     2>&1 | grep -E "(Loading|Rendering|error|Error|SPP)"

# Take snapshot
java -Dchunky.home=/opt/chunky \
     -jar ChunkyLauncher.jar \
     -scene-dir "$SCENE_DIR" \
     -snapshot "$SCENE_NAME" "$TEMP" \
     2>/dev/null

# Check if render succeeded (file should be > 10KB for a real render)
if [ ! -f "$TEMP" ] || [ $(stat -c%s "$TEMP" 2>/dev/null || echo 0) -lt 10000 ]; then
    echo "Chunky render failed or too small, falling back to unmined"
    # Fallback to unmined with 3D shadows (area matches FOV-based range)
    /opt/minecraft/unmined-cli_0.19.54-dev_linux-x64/unmined-cli image render \
        --world=/opt/minecraft/world \
        --output="$TEMP" \
        --area="b(($((CAM_X-RANGE)),$((CAM_Z-RANGE))),($((CAM_X+RANGE/2)),$((CAM_Z+RANGE/2))))" \
        --zoom=2 \
        --shadows=3d \
        --trim 2>/dev/null
fi

# Create small version of logo (80px height)
convert "$LOGO" -resize x80 "$LOGO_SMALL"

# Add timestamp (top right) and logo (bottom left)
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M UTC')
convert "$TEMP" \
    -gravity NorthEast \
    -font DejaVu-Sans-Mono-Bold \
    -pointsize 18 \
    -fill white \
    -stroke red \
    -strokewidth 2 \
    -annotate +8+8 "$TIMESTAMP" \
    \( "$LOGO_SMALL" \) -gravity SouthWest -geometry +5+5 -composite \
    "$OUTPUT"

rm -f "$TEMP" "$LOGO_SMALL"
echo "Isometric render completed with timestamp: $TIMESTAMP"

# Trigger background render (runs in background at low priority)
nohup /opt/minecraft/render_background.sh > /tmp/bg_render.log 2>&1 &
