#!/bin/bash
# Render detail/3D view of spawn area with timestamp and logo overlay

OUTPUT="/mnt/shared/spawn_detail.png"
TEMP="/tmp/spawn_detail_raw.png"
LOGO="/mnt/shared/jee.bz.png"
LOGO_SMALL="/tmp/jee_logo_small_detail.png"

# Render the detail map (80x80 blocks centered on -160,-330, zoom 2, 3D shadows)
/opt/minecraft/unmined-cli_0.19.54-dev_linux-x64/unmined-cli image render \
    --world=/opt/minecraft/world \
    --output="$TEMP" \
    --area="b((-200,-370),(-120,-290))" \
    --zoom=2 \
    --shadows=3d \
    --trim 2>/dev/null

# Create small version of logo (80px height)
convert "$LOGO" -resize x80 "$LOGO_SMALL"

# Add timestamp (top right) and logo (bottom left)
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M UTC')
convert "$TEMP" \
    -gravity NorthEast \
    -font DejaVu-Sans-Mono \
    -pointsize 12 \
    -fill white \
    -stroke black \
    -strokewidth 1 \
    -annotate +5+5 "$TIMESTAMP" \
    \( "$LOGO_SMALL" \) -gravity SouthWest -geometry +5+5 -composite \
    "$OUTPUT"

rm -f "$TEMP" "$LOGO_SMALL"
echo "Detail map rendered with timestamp: $TIMESTAMP"
