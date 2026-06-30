#!/bin/bash

UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	for NAME in "${PKG_LIST[@]}"; do
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not found directory: $NAME"
		fi
	done

	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# ========== 主题类 ==========
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"

# ========== 科学上网类 ==========
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"

# ========== 网络工具类 ==========
UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"

# ========== 核心插件类 ==========
UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "kix"
UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"
UPDATE_PACKAGE "luci-app-lucky" "sirpdboy/luci-app-lucky" "main"

# ========== Docker 管理类 ==========
UPDATE_PACKAGE "luci-lib-docker" "lisaac/luci-lib-docker" "master"
if [ -d "luci-lib-docker" ]; then
	find luci-lib-docker -name "Makefile" \
		-exec sed -i 's/PKG_VERSION:=v\([0-9]\)/PKG_VERSION:=\1/g' {} +
	echo "luci-lib-docker version fix done"
else
	echo "luci-lib-docker clone failed"
fi

UPDATE_PACKAGE "luci-app-dockerman" "lisaac/luci-app-dockerman" "master"
if [ -d "luci-app-dockerman" ]; then
	find luci-app-dockerman -name "Makefile" \
		-exec sed -i 's/PKG_VERSION:=v\([0-9]\)/PKG_VERSION:=\1/g' {} +
	echo "luci-app-dockerman version fix done"
else
	echo "luci-app-dockerman clone failed"
fi

# ========== 文件共享类 ==========
UPDATE_PACKAGE "luci-app-unishare" "linkease/luci-app-unishare" "main"

# ========== 删除 feeds 中的官方重复包 ==========
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dae*,bypass*}
rm -rf ../feeds/packages/net/{v2ray-geodata,dae*}
cp -r $GITHUB_WORKSPACE/package/* ./

# ========== 修复 daed/Makefile ==========
sed -i 's/pnpm install ; \\/pnpm install --no-frozen-lockfile ; \\/g' luci-app-daed/daed/Makefile
sed -i 's|github.com/daeuniverse/quic-go|github.com/olicesx/quic-go|g' luci-app-daed/daed/Makefile
sed -i 's|/run/i\\  procd_set_param|/procd_set_param command/i \\\tprocd_set_param|g' luci-app-daed/luci-app-daed/root/etc/init.d/luci_daed
