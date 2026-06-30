#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/$WRT_DIR/package/"

if [ -d "luci-theme-argon" ]; then
	cd ./luci-theme-argon/ || exit 0
	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon
	cd $PKG_PATH || exit 0
fi

TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	sed -i '/\/files/d' "$TS_FILE"
fi

RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE"
fi

DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
	sed -i '/ntfs-3g-utils /d' "$DM_FILE"
fi

OPKG_FEEDS_DIR="$GITHUB_WORKSPACE/$WRT_DIR/files/etc/opkg"
mkdir -p "$OPKG_FEEDS_DIR"
cat > "$OPKG_FEEDS_DIR/customfeeds.conf" << 'EOF'
src/gz kwrt_base     https://dl.openwrt.ai/releases/25.12/packages/aarch64_cortex-a53/base
src/gz kwrt_packages https://dl.openwrt.ai/releases/25.12/packages/aarch64_cortex-a53/packages
src/gz kwrt_luci     https://dl.openwrt.ai/releases/25.12/packages/aarch64_cortex-a53/luci
src/gz kwrt_routing  https://dl.openwrt.ai/releases/25.12/packages/aarch64_cortex-a53/routing
src/gz kwrt_video    https://dl.openwrt.ai/releases/25.12/packages/aarch64_cortex-a53/video
src/gz kwrt_kiddin9  https://dl.openwrt.ai/releases/25.12/packages/aarch64_cortex-a53/kiddin9
src/gz kenzo         https://down.dllkids.xyz/openwrt-feed/24.10/aarch64_cortex-a53
EOF
