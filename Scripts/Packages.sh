#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/$WRT_DIR/package/"
WRT_PATH="$GITHUB_WORKSPACE/$WRT_DIR"

# ========================================================
# 一、注册 kenzok8 三个 feeds
# 说明：WRT-CORE.yml 的 feeds update/install 已提前执行
#       此处注册后执行二次 feeds，确保 kenzok8 包进入编译系统
# ========================================================
cd $WRT_PATH

grep -q "kenzok8/openwrt-packages" feeds.conf.default || \
    sed -i '1i src-git kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default

grep -q "kenzok8/small" feeds.conf.default || \
    sed -i '2i src-git small https://github.com/kenzok8/small' feeds.conf.default

grep -q "kenzok8/openwrt-daede" feeds.conf.default || \
    sed -i '3i src-git daede https://github.com/kenzok8/openwrt-daede' feeds.conf.default

echo "kenzok8 feeds registered!"

# small 官方要求替换 golang（用于正确构建依赖链）
rm -rf feeds/packages/lang/golang
git clone --depth=1 -b 1.26 https://github.com/kenzok8/golang feeds/packages/lang/golang
echo "golang replaced with kenzok8/golang 1.26!"

# 仅更新新注册的三个 feed，不重复更新已有 feed
./scripts/feeds update kenzo small daede
echo "kenzok8 feeds update done!"

# ========================================================
# 二、清理冲突包（必须在 feeds install 之前完成）
# ========================================================

# 2-1 kenzok8 官方 README 明确的系统级冲突包
#     这些包会破坏 immortalwrt 系统级组件，必须删除
rm -rf feeds/small/{base-files,dnsmasq,firewall*,fullconenat,libnftnl,nftables,ppp,opkg,ucl,upx,vsftpd*,miniupnpd-iptables,wireless-regdb}
rm -rf feeds/kenzo/{base-files,dnsmasq,firewall*,fullconenat,libnftnl,nftables,ppp,opkg,ucl,upx,vsftpd*,miniupnpd-iptables,wireless-regdb}
echo "system-level conflict packages removed!"

# 2-2 small 官方要求额外清理（与 immortalwrt 官方 feeds 重复）
rm -rf feeds/packages/net/{alist,adguardhome,mosdns,xray*,v2ray*,sing*,smartdns}
rm -rf feeds/packages/utils/v2dat
echo "small extra conflict packages removed!"

# 2-3 immortalwrt 25.12 官方 feeds 已维护的重复包
#     防止 kenzok8 旧版本覆盖官方维护版本
rm -rf feeds/kenzo/luci-app-upnp
rm -rf feeds/kenzo/luci-app-ttyd
rm -rf feeds/kenzo/luci-app-ddns-go
rm -rf feeds/kenzo/luci-proto-wireguard
echo "immortalwrt duplicate packages removed!"

# 2-4 修复 kenzok8 dockerman 版本号格式
#     kenzok8 版本号带 v 前缀（如 v0.5.x），immortalwrt 编译系统不识别
#     直接在 feeds/kenzo/ 目录修复，无需额外 clone
find feeds/kenzo/luci-app-dockerman feeds/kenzo/luci-lib-docker \
    -name "Makefile" \
    -exec sed -i 's/PKG_VERSION:=v\([0-9]\)/PKG_VERSION:=\1/g' {} + 2>/dev/null
echo "dockerman version prefix fixed!"

# ========================================================
# 三、执行二次 feeds install
#     冲突包清理完毕后统一注册，确保干净
# ========================================================
./scripts/feeds install -a
echo "kenzok8 feeds install done!"

# ========================================================
# 四、进入 package/ 目录处理 kenzok8 没有的包
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
        local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ \
            -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

        if [ -n "$FOUND_DIRS" ]; then
            while read -r DIR; do
                rm -rf "$DIR"
                echo "Delete directory: $DIR"
            done <<< "$FOUND_DIRS"
        else
            echo "Not found directory: $NAME"
        fi
    done

    git clone --depth=1 --single-branch --branch $PKG_BRANCH \
        "https://github.com/$PKG_REPO.git"

    if [[ "$PKG_SPECIAL" == "pkg" ]]; then
        find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" \
            -prune -exec cp -rf {} ./ \;
        rm -rf ./$REPO_NAME/
    elif [[ "$PKG_SPECIAL" == "name" ]]; then
        mv -f $REPO_NAME $PKG_NAME
    fi
}

# openlist2：sbwml 独立维护，kenzok8 未收录
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"

# unishare：linkease 独立维护，kenzok8 未收录
UPDATE_PACKAGE "luci-app-unishare" "linkease/luci-app-unishare" "main"

# viking：VIKINGYFY 独立维护，kenzok8 未收录
# wolplus=n 不会编译，保留 clone 便于随时启用
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"

# ========================================================
# 五、复制仓库预置包
#     v2ray-geodata 保留参与编译
#     dae/luci-app-dae 仓库中保留但不参与编译
#     （kenzok8/daede feed 已提供替代）
# ========================================================

# 清理 immortalwrt feeds 中与自定义包重复的残留
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dae*,bypass*}
rm -rf ../feeds/packages/net/{v2ray-geodata,dae*}

# 复制仓库预置包（含 dae/ luci-app-dae/ v2ray-geodata/）
cp -r $GITHUB_WORKSPACE/package/* ./

# 删除编译目录中复制进来的 QiuSimons dae 包
# 仓库文件本身保留不动，只删除编译目录副本
# kenzok8/daede feed 的 dae+daed+luci-app-daede 将替代它们
rm -rf ./dae
rm -rf ./luci-app-dae
echo "QiuSimons dae/luci-app-dae removed from build dir (repo kept intact)"
echo "kenzok8/daede will be used for dae/daed/luci-app-daede"

echo "Packages.sh all done!"
