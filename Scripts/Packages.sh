#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/$WRT_DIR/package/"
WRT_PATH="$GITHUB_WORKSPACE/$WRT_DIR"

cd $WRT_PATH

grep -q "kenzok8/openwrt-packages" feeds.conf.default || \
    sed -i '1i src-git kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default

grep -q "kenzok8/small" feeds.conf.default || \
    sed -i '2i src-git small https://github.com/kenzok8/small' feeds.conf.default

grep -q "kenzok8/openwrt-daede" feeds.conf.default || \
    sed -i '3i src-git daede https://github.com/kenzok8/openwrt-daede' feeds.conf.default

echo "kenzok8 feeds registered!"

rm -rf feeds/packages/lang/golang
git clone --depth=1 --single-branch -b 1.26 \
    https://github.com/kenzok8/golang \
    feeds/packages/lang/golang
echo "golang replaced with kenzok8/golang 1.26!"

./scripts/feeds update kenzo small daede
echo "kenzok8 feeds update done!"

rm -rf feeds/small/{base-files,dnsmasq,firewall*,fullconenat,libnftnl,nftables,ppp,opkg,ucl,upx,vsftpd*,miniupnpd-iptables,wireless-regdb}
rm -rf feeds/kenzo/{base-files,dnsmasq,firewall*,fullconenat,libnftnl,nftables,ppp,opkg,ucl,upx,vsftpd*,miniupnpd-iptables,wireless-regdb}
echo "system-level conflict packages removed!"

rm -rf feeds/packages/net/{alist,adguardhome,mosdns,xray*,v2ray*,sing*,smartdns}
rm -rf feeds/packages/utils/v2dat
echo "small extra conflict packages removed!"

rm -rf feeds/kenzo/luci-app-upnp
rm -rf feeds/kenzo/luci-app-ttyd
rm -rf feeds/kenzo/luci-app-ddns-go
rm -rf feeds/kenzo/luci-proto-wireguard
echo "immortalwrt duplicate packages removed!"

for DOCKER_PKG in feeds/kenzo/luci-app-dockerman feeds/kenzo/luci-lib-docker; do
    if [ -f "$DOCKER_PKG/Makefile" ]; then
        sed -i 's/PKG_VERSION:=v\([0-9]\)/PKG_VERSION:=\1/g' "$DOCKER_PKG/Makefile"
        echo "$DOCKER_PKG version prefix fixed!"
    else
        echo "WARNING: $DOCKER_PKG/Makefile not found, skip version fix"
    fi
done

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


UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"

rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dae*,bypass*}
rm -rf ../feeds/packages/net/{v2ray-geodata,dae*}
echo "immortalwrt feeds residual packages removed!"

cp -r $GITHUB_WORKSPACE/package/* ./
rm -rf ./dae
rm -rf ./luci-app-dae
echo "QiuSimons dae/luci-app-dae removed from build dir!"
echo "kenzok8/daede feed provides dae + daed + luci-app-daede!"
echo "v2ray-geodata kept for v2ray-geodata-updater!"

echo "========================================"
echo "Packages.sh completed successfully!"
echo "========================================"
