nushell_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}  # Default to amd64 if no architecture specified

if [ -z "$nushell_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <nushell_version> <build_version> [architecture]"
    echo "Example: $0 0.114.1 1 arm64"
    echo "Example: $0 0.114.1 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64, armhf, riscv64, all"
    exit 1
fi

# Function to map Debian architecture to nushell release target triple.
# musl builds are fully static — the right choice for a login shell — and are
# used wherever upstream publishes them; riscv64 only has a glibc build.
get_nu_release() {
    local arch=$1
    case "$arch" in
        "amd64")
            echo "nu-${nushell_VERSION}-x86_64-unknown-linux-musl"
            ;;
        "arm64")
            echo "nu-${nushell_VERSION}-aarch64-unknown-linux-musl"
            ;;
        "armhf")
            echo "nu-${nushell_VERSION}-armv7-unknown-linux-musleabihf"
            ;;
        "riscv64")
            echo "nu-${nushell_VERSION}-riscv64gc-unknown-linux-gnu"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to build for a specific architecture
build_architecture() {
    local build_arch=$1
    local nu_release

    nu_release=$(get_nu_release "$build_arch")
    if [ -z "$nu_release" ]; then
        echo "❌ Unsupported architecture: $build_arch"
        echo "Supported architectures: amd64, arm64, armhf, riscv64"
        return 1
    fi

    echo "Building for architecture: $build_arch using $nu_release"

    # Clean up any previous builds for this architecture
    rm -rf "$nu_release" || true
    rm -f "${nu_release}.tar.gz" || true

    # Download and extract the nushell tarball (nu + plugins) for this architecture
    if ! wget -q "https://github.com/nushell/nushell/releases/download/${nushell_VERSION}/${nu_release}.tar.gz"; then
        echo "❌ Failed to download nushell tarball for $build_arch"
        return 1
    fi

    if ! tar -xf "${nu_release}.tar.gz"; then
        echo "❌ Failed to extract nushell tarball for $build_arch"
        return 1
    fi

    rm -f "${nu_release}.tar.gz"

    # Keep nu + the official plugins; drop docs and the demo/test-only plugins
    # (example, custom_values, stress_internals are development samples).
    rm -f "$nu_release/LICENSE" "$nu_release/README.txt" \
          "$nu_release/nu_plugin_example" \
          "$nu_release/nu_plugin_custom_values" \
          "$nu_release/nu_plugin_stress_internals"

    # Build packages for appropriate Ubuntu distributions
    # riscv64 is only supported from noble (24.04) onwards
    if [ "$build_arch" = "riscv64" ]; then
        declare -a arr=("noble" "questing" "resolute")
    else
        declare -a arr=("jammy" "noble" "questing" "resolute")
    fi

    for dist in "${arr[@]}"; do
        FULL_VERSION="$nushell_VERSION-${BUILD_VERSION}~${dist}_${build_arch}_ubu"
        echo "  Building $FULL_VERSION"

        if ! docker build . -f Dockerfile.ubu -t "nushell-ubuntu-$dist-$build_arch" \
            --build-arg UBUNTU_DIST="$dist" \
            --build-arg nushell_VERSION="$nushell_VERSION" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION" \
            --build-arg ARCH="$build_arch" \
            --build-arg NU_RELEASE="$nu_release"; then
            echo "❌ Failed to build Docker image for $dist on $build_arch"
            return 1
        fi

        id="$(docker create "nushell-ubuntu-$dist-$build_arch")"
        if ! docker cp "$id:/nushell_$FULL_VERSION.deb" - > "./nushell_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb package for $dist on $build_arch"
            return 1
        fi

        if ! tar -xf "./nushell_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb contents for $dist on $build_arch"
            return 1
        fi
    done

    # Clean up extracted directory
    rm -rf "$nu_release" || true

    echo "✅ Successfully built for $build_arch"
    return 0
}

# Main build logic
if [ "$ARCH" = "all" ]; then
    echo "🚀 Building nushell $nushell_VERSION-$BUILD_VERSION for all supported architectures..."
    echo ""

    ARCHITECTURES=("amd64" "arm64" "armhf" "riscv64")

    for build_arch in "${ARCHITECTURES[@]}"; do
        echo "==========================================="
        echo "Building for architecture: $build_arch"
        echo "==========================================="

        if ! build_architecture "$build_arch"; then
            echo "❌ Failed to build for $build_arch"
            exit 1
        fi

        echo ""
    done

    echo "🎉 All architectures built successfully!"
    echo "Generated packages:"
    ls -la nushell_*.deb
else
    # Build for single architecture
    if ! build_architecture "$ARCH"; then
        exit 1
    fi
fi
