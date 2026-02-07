#!/bin/bash
# Render spawn map with timestamp and logo overlay

OUTPUT="/mnt/shared/spawn_map.png"
TEMP="/tmp/spawn_map_raw.png"
LOGO="/mnt/shared/jee.bz.png"
LOGO_SMALL="/tmp/jee_logo_small.png"

# Render the map
/opt/minecraft/unmined-cli_0.19.54-dev_linux-x64/unmined-cli image render \
    --world=/opt/minecraft/world \
    --output="$TEMP" \
    --area="b((-285,159),(227,671))" \
    --zoom=0 \
    --trim 2>/dev/null

# Create small version of logo (40px height)
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
echo "Map rendered with timestamp: $TIMESTAMP"
