#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/$WRT_DIR/package/"

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " "

	cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

#修复DiskMan编译失败
DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
	echo " "

	sed -i '/ntfs-3g-utils /d' $DM_FILE

	cd $PKG_PATH && echo "diskman has been fixed!"
fi

#预置 opkg 自定义软件源（写入 files/ overlay，随固件打包）
#
# 源分工说明：
#   Kiddin9源(dl.openwrt.ai/25.12) → .ipk格式，25.12体系，版本完全匹配
#   kenzok8源(down.dllkids.xyz/24.10) → .ipk格式，补充科学插件（daed/clashoo等）
#
# 模式说明：
#   CONFIG_USE_APK=n（opkg模式）→ 此文件生效，opkg update 自动读取
#   CONFIG_USE_APK=y（APK模式） → 此文件存在于rootfs但不被apk读取，无副作用
OPKG_FEEDS_DIR="$GITHUB_WORKSPACE/$WRT_DIR/files/etc/opkg"
mkdir -p $OPKG_FEEDS_DIR
cat > $OPKG_FEEDS_DIR/customfeeds.conf << 'EOF'
src/gz kwrt_base     https://dl.openwrt.ai/releases/25.12/packages/aarch64_cortex-a53/base
src/gz kwrt_packages https://dl.openwrt.ai/releases/25.12/packages/aarch64_cortex-a53/packages
src/gz kwrt_luci     https://dl.openwrt.ai/releases/25.12/packages/aarch64_cortex-a53/luci
src/gz kwrt_routing  https://dl.openwrt.ai/releases/25.12/packages/aarch64_cortex-a53/routing
src/gz kwrt_video    https://dl.openwrt.ai/releases/25.12/packages/aarch64_cortex-a53/video
src/gz kwrt_kiddin9  https://dl.openwrt.ai/releases/25.12/packages/aarch64_cortex-a53/kiddin9
src/gz kenzo         https://down.dllkids.xyz/openwrt-feed/24.10/aarch64_cortex-a53
EOF
echo "opkg customfeeds.conf has been preset!"
