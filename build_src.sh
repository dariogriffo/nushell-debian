#!/bin/bash
set -euo pipefail

nushell_VERSION=$1
BUILD_VERSION=$2

if [ -z "$nushell_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <nushell_version> <build_version>"
    echo "Example: $0 0.114.1 1"
    exit 1
fi

PACKAGE_NAME="nushell"
ORIG_TARBALL="${PACKAGE_NAME}_${nushell_VERSION}.orig.tar.gz"
BUILD_DIR="${PACKAGE_NAME}-${nushell_VERSION}"

echo "Creating the source package for nushell ${nushell_VERSION}-${BUILD_VERSION}..."

# Download upstream source tarball (shared .orig.tar.gz across all distributions)
if [ ! -f "$ORIG_TARBALL" ]; then
    echo "Downloading upstream source from GitHub..."
    wget -q "https://github.com/nushell/nushell/archive/refs/tags/${nushell_VERSION}.tar.gz" -O "$ORIG_TARBALL"
    echo "  ✅ Downloaded $ORIG_TARBALL"
else
    echo "  ✅ Using existing $ORIG_TARBALL"
fi

build_source_package() {
    local FULL_VERSION="${nushell_VERSION}-${BUILD_VERSION}~griffo"

    echo "  Building source package ${FULL_VERSION}..."

    # Clean and recreate build directory from orig tarball
    rm -rf "$BUILD_DIR"
    tar -xf "$ORIG_TARBALL"
    # GitHub archives extract as nushell-0.x.y/ which matches our BUILD_DIR

    # Copy Debian packaging directory
    cp -r debian "$BUILD_DIR/"

    # Generate the changelog (overwrites placeholder)
    cat > "$BUILD_DIR/debian/changelog" << EOF
nushell (${FULL_VERSION}) stable; urgency=medium

  * New upstream release ${nushell_VERSION}.

 -- Dario Griffo <dariogriffo@gmail.com>  $(date -R)
EOF

    # Build source package (.dsc + .debian.tar.xz); reuses existing .orig.tar.gz
    dpkg-source -b "$BUILD_DIR"

    rm -rf "$BUILD_DIR"
    echo "    ✅ ${FULL_VERSION}"
}

echo ""
# One source package for every suite, as with the binaries (see build_debian.sh).
build_source_package

echo ""
echo "🎉 Source packages created successfully!"
echo ""
echo "Generated files:"
ls -la "${PACKAGE_NAME}_"*.dsc "${PACKAGE_NAME}_"*.orig.tar.gz "${PACKAGE_NAME}_"*.debian.tar.xz 2>/dev/null || true
