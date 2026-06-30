#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/$WRT_DIR/package/"
WRT_PATH="$GITHUB_WORKSPACE/$WRT_DIR"

# ========================================================
# 一、注册 kenzok8 feeds（在 feeds update 之前）
# ========================================================
cd $WRT_PATH

# 防止重复注册（多次运行脚本时幂等）
grep -q "kenzok8/openwrt-packages" feeds.conf.default || \
    sed -i '1i src-git kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default

grep -q "kenzok8/small" feeds.conf.default || \
    sed -i '2i src-git small https://github.com/kenzok8/small' feeds.conf.default

echo "kenzok8 feeds registered!"

# ========================================================
# 二、执行 feeds update
# ========================================================
./scripts/feeds update -a
echo "feeds update done!"

# ========================================================
# 三、清理冲突包
# 顺序：官方冲突列表 → immortalwrt 25.12 特有冲突 → 
#       packages.sh 内 UPDATE_PACKAGE 会精准覆盖的包
# ========================================================

# 3-1 kenzok8 官方 README 明确给出的冲突列表
# 这些包会破坏系统级组件，必须删除
rm -rf feeds/small/{base-files,dnsmasq,firewall*,fullconenat,libnftnl,nftables,ppp,opkg,ucl,upx,vsftpd*,miniupnpd-iptables,wireless-regdb}
rm -rf feeds/kenzo/{base-files,dnsmasq,firewall*,fullconenat,libnftnl,nftables,ppp,opkg,ucl,upx,vsftpd*,miniupnpd-iptables,wireless-regdb}
echo "official conflict packages removed!"

# 3-2 immortalwrt 25.12 feeds 已有的重复包
# 防止 kenzok8 旧版本覆盖 immortalwrt 官方维护的版本
rm -rf feeds/kenzo/luci-app-upnp
rm -rf feeds/kenzo/luci-app-ttyd
rm -rf feeds/kenzo/luci-app-diskman
rm -rf feeds/kenzo/luci-app-ddns-go
rm -rf feeds/kenzo/luci-proto-wireguard
echo "immortalwrt duplicate packages removed!"

# 3-3 packages.sh 内 UPDATE_PACKAGE 会精准覆盖的包
# 这些包由原作者仓库 clone，版本更新，必须先删除 kenzok8 版本

# argon 主题 → 由 sbwml 最新版覆盖
rm -rf feeds/kenzo/luci-theme-argon
rm -rf feeds/small/luci-theme-argon

# dockerman 套件 → 由 lisaac 最新版覆盖 + 版本号修复
# 这是保证 luci-app-dockerman 不出问题的关键步骤
rm -rf feeds/kenzo/luci-app-dockerman
rm -rf feeds/small/luci-app-dockerman
rm -rf feeds/kenzo/luci-lib-docker
rm -rf feeds/small/luci-lib-docker
echo "dockerman conflict packages removed!"

# daed/dae 相关 → 由 QiuSimons/kix 版本覆盖
rm -rf feeds/kenzo/luci-app-daed
rm -rf feeds/small/luci-app-daed
rm -rf feeds/kenzo/dae
rm -rf feeds/small/dae
rm -rf feeds/kenzo/daed
rm -rf feeds/small/daed
echo "daed conflict packages removed!"

# nikki/mihomo → 由原作者仓库覆盖
rm -rf feeds/kenzo/luci-app-nikki
rm -rf feeds/small/luci-app-nikki
rm -rf feeds/kenzo/nikki
rm -rf feeds/small/nikki

# mosdns → 由 sbwml 版本覆盖（若启用）
rm -rf feeds/kenzo/luci-app-mosdns
rm -rf feeds/small/luci-app-mosdns

# openlist → 由 sbwml 版本覆盖
rm -rf feeds/kenzo/luci-app-openlist2
rm -rf feeds/small/luci-app-openlist2

# pushbot / lucky → 由原作者仓库覆盖
rm -rf feeds/kenzo/luci-app-pushbot
rm -rf feeds/small/luci-app-pushbot
rm -rf feeds/kenzo/luci-app-lucky
rm -rf feeds/small/luci-app-lucky

# unishare → 由 linkease 仓库覆盖
rm -rf feeds/kenzo/luci-app-unishare
rm -rf feeds/small/luci-app-unishare

echo "UPDATE_PACKAGE override targets removed!"

# ========================================================
# 四、执行 feeds install
# 在冲突包清理完成后再 install，保证干净注册
# ========================================================
./scripts/feeds install -a
echo "feeds install done!"

# ========================================================
# 五、进入 package/ 目录执行精准覆盖
# UPDATE_PACKAGE 的版本优先于 kenzok8 feeds
# ========================================================
cd $PKG_PATH

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
# 说明：kenzok8 feeds 中的 dockerman 和 luci-lib-docker 已在第三步删除
# 此处从 lisaac 原仓库 clone 最新版，并修复版本号格式
# 这是保证 luci-app-dockerman 编译正常的完整闭环：
#   删除kenzok8版本 → clone lisaac版本 → 修复版本号 → 编译通过
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

# ========================================================
# 六、删除 feeds 中的官方重复包（防止自定义 clone 与之冲突）
# ========================================================
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dae*,bypass*}
rm -rf ../feeds/packages/net/{v2ray-geodata,dae*}
cp -r $GITHUB_WORKSPACE/package/* ./

# ========================================================
# 七、修复 daed/Makefile
# ========================================================
sed -i 's/pnpm install ; \\/pnpm install --no-frozen-lockfile ; \\/g' luci-app-daed/daed/Makefile
sed -i 's|github.com/daeuniverse/quic-go|github.com/olicesx/quic-go|g' luci-app-daed/daed/Makefile
sed -i 's|/run/i\\  procd_set_param|/procd_set_param command/i \\\tprocd_set_param|g' luci-app-daed/luci-app-daed/root/etc/init.d/luci_daed
echo "daed Makefile fixed!"
