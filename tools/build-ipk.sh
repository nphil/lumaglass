#!/bin/sh
set -e

# LumaGlass IPK builder
# Builds org.nphil.lumaglass_<version>_all.ipk without webOS SDK dependency

# Determine repo root (this script is tools/build-ipk.sh)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Parse options
DRY_RUN=0
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=1
fi

# Read version from appinfo.json
VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' appinfo.json | grep -o '[0-9.]*')
if [ -z "$VERSION" ]; then
    echo "Error: cannot read version from appinfo.json" >&2
    exit 1
fi

# Define required inputs
REQUIRED_FILES="
appinfo.json
index.html
app.js
style.css
assets/icon.png
assets/largeIcon.png
assets/splash.png
tools/lumaglass
tools/autostart.sh
tools/keyfilter.py
payload/compositor/StarfishFullscreenContainer.qml
payload/compositor/lumaglass/LumaHome.qml
payload/keyfilter/lumaglass.js
payload/home/home.xml
payload/home/en.json.sed
payload/wallpaper/wall_1080.png
payload/theme/theme.json
payload/theme/layout.json
payload/fonts/Manrope-SemiBold.ttf
"

# Check required files
MISSING=""
for FILE in $REQUIRED_FILES; do
    if [ ! -e "$FILE" ]; then
        MISSING="$MISSING $FILE"
    fi
done

if [ "$DRY_RUN" = "1" ]; then
    echo "Dry run: checking required inputs"
    echo "Version: $VERSION"
    echo "---"
    for FILE in $REQUIRED_FILES; do
        if [ -e "$FILE" ]; then
            echo "✓ $FILE"
        else
            echo "✗ $FILE (missing)"
        fi
    done
    exit 0
fi

# Real build: fail if any inputs missing
if [ -n "$MISSING" ]; then
    echo "Error: missing required files:$MISSING" >&2
    exit 1
fi

# Clean build directory
BUILD_DIR="./build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Stage data root: usr/palm/applications/org.nphil.lumaglass/
DATA_ROOT="$BUILD_DIR/data/usr/palm/applications/org.nphil.lumaglass"
mkdir -p "$DATA_ROOT"

# Copy application files (repo root)
cp appinfo.json "$DATA_ROOT/"
cp index.html "$DATA_ROOT/"
cp app.js "$DATA_ROOT/"
cp style.css "$DATA_ROOT/"
cp assets/icon.png "$DATA_ROOT/"
cp assets/largeIcon.png "$DATA_ROOT/"
cp assets/splash.png "$DATA_ROOT/"

# Copy tools with execute bit
mkdir -p "$DATA_ROOT/tools"
cp tools/lumaglass "$DATA_ROOT/tools/"
chmod 755 "$DATA_ROOT/tools/lumaglass"
cp tools/autostart.sh "$DATA_ROOT/tools/"
chmod 755 "$DATA_ROOT/tools/autostart.sh"

# Copy the payload tree as-is: the tool stages directories (compositor QML,
# theme, fonts) rather than single files.
mkdir -p "$DATA_ROOT/payload"
cp -R payload/. "$DATA_ROOT/payload/"
cp tools/tileicons.js "$DATA_ROOT/tools/"
cp tools/keyfilter.py "$DATA_ROOT/tools/"

# Create deterministic data.tar.gz
# Use fixed mtime, owner/group 0, sorted filenames
cd "$BUILD_DIR/data"
tar \
    --sort=name \
    --owner=0 --group=0 --numeric-owner \
    --mtime='1970-01-01 00:00:00 UTC' \
    -czf ../data.tar.gz .
cd - > /dev/null

# Create control file
CONTROL_DIR="$BUILD_DIR/control"
mkdir -p "$CONTROL_DIR"
cat > "$CONTROL_DIR/control" << EOF
Package: org.nphil.lumaglass
Version: $VERSION
Architecture: all
Maintainer: nphil
Description: Liquid glass home screen for rooted LG webOS TVs
 Reskins the stock LG webOS 10 Home screen with a compositor-level
 liquid glass material, generated abstract wallpaper, and decluttered layout.
EOF

# Create deterministic control.tar.gz
cd "$CONTROL_DIR"
tar \
    --sort=name \
    --owner=0 --group=0 --numeric-owner \
    --mtime='1970-01-01 00:00:00 UTC' \
    -czf ../control.tar.gz control
cd - > /dev/null

# Create debian-binary
echo "2.0" > "$BUILD_DIR/debian-binary"

# Create ar archive in deterministic order: debian-binary, control.tar.gz, data.tar.gz
IPK_NAME="org.nphil.lumaglass_${VERSION}_all.ipk"
IPK_PATH="$(cd "$REPO_ROOT" && pwd)/$IPK_NAME"
rm -f "$IPK_NAME"
ar rc "$IPK_NAME" \
    "$BUILD_DIR/debian-binary" \
    "$BUILD_DIR/control.tar.gz" \
    "$BUILD_DIR/data.tar.gz"

# Verify the archive
echo "Verifying IPK structure..."
IPK_FULL_PATH="$REPO_ROOT/$IPK_NAME"
AR_MEMBERS=$(ar t "$IPK_FULL_PATH")
EXPECTED_MEMBERS="debian-binary
control.tar.gz
data.tar.gz"

if [ "$AR_MEMBERS" != "$EXPECTED_MEMBERS" ]; then
    echo "Error: IPK members mismatch" >&2
    echo "Expected:" >&2
    echo "$EXPECTED_MEMBERS" >&2
    echo "Got:" >&2
    echo "$AR_MEMBERS" >&2
    exit 1
fi

# Extract and verify contents
VERIFY_DIR="$BUILD_DIR/verify"
mkdir -p "$VERIFY_DIR"
cd "$VERIFY_DIR"
ar x "$IPK_FULL_PATH"
tar -tzf data.tar.gz > data_files.txt
cd - > /dev/null

# Compute IPK hash
IPK_SHA256=$(sha256sum "$IPK_FULL_PATH" | awk '{print $1}')
IPK_SIZE=$(stat -c%s "$IPK_FULL_PATH")

# Report results
echo "✓ IPK built successfully"
echo "File: $IPK_NAME"
echo "Size: $IPK_SIZE bytes"
echo "SHA256: $IPK_SHA256"
echo "---"
echo "Contents (data.tar.gz):"
tar -tzf "$BUILD_DIR/verify/data.tar.gz" | grep -v '^$' | sort
