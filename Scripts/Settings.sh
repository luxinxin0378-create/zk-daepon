#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识及构建者
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_DATE \/ build by zk6685')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

# 概览页 Firmware Version 字段包成本仓库超链接(构造 E('a') 节点, 避免被 E() 转义为纯文本)
python3 - <<'PYEOF'
import re, glob, sys
for path in glob.glob("./feeds/luci/modules/luci-mod-status/**/10_system.js", recursive=True):
    try:
        s = open(path).read()
    except Exception as e:
        print("skip %s: %s" % (path, e)); continue
    pat = re.compile(r"(_\('Firmware Version'\),\s*)(.+?),\n", re.M)
    new = pat.sub(
        lambda m: m.group(1) + "E('a', { 'href': 'https://github.com/zk6685/zk-daepon', 'target': '_blank' }, [ " + m.group(2) + " ]),\n",
        s)
    if new != s:
        open(path, 'w').write(new)
        print("patched: %s" % path)
    else:
        print("no change: %s" % path)
PYEOF

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	#修改WIFI加密
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#设置NSS版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	#其他调整
	echo "CONFIG_PACKAGE_kmod-usb-serial-qualcomm=y" >> ./.config

	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi

#调整网口顺序
sed -i 's/ucidef_set_interface_lan "lan1 lan2 lan3 lan4"/ucidef_set_interfaces_lan_wan "lan1 lan2 lan3" "lan4"/g' target/linux/airoha/an7581/base-files/etc/board.d/02_network
sed -i 's/interrupts.*//g' target/linux/airoha/dts/an7581-nokia_xg-040g-md-common.dtsi

# ==============================================================================
# === CUSTOM-ONU2 BEGIN ===  定制：root 密码 / LAN IP / WiFi
# ==============================================================================
if [ "$WRT_CONFIG" = "CUSTOM-ONU2" ]; then
	# 1) 编译期写入 root 密码（md5-crypt of "root"）
	SHADOW="./package/base-files/files/etc/shadow"
	if [ -f "$SHADOW" ]; then
		sed -i 's|^root:[^:]*:|root:$1$WrT2026$TS7rClERv7a4V0C9vdJc4/:|' "$SHADOW"
		echo "[CUSTOM-ONU2] root password -> root (shadow)"
	else
		echo "[CUSTOM-ONU2] WARN: $SHADOW not found"
	fi

	# 2) 首次启动兜底：LAN IP / root 密码 / WiFi 名称与密码
	mkdir -p ./files/etc/uci-defaults
	cat > ./files/etc/uci-defaults/99-custom-init <<'CUSTOM_EOF'
#!/bin/sh
# LAN IP
uci -q set network.lan.ipaddr='192.168.2.1'
uci -q commit network
# root 密码
(echo 'root'; sleep 1; echo 'root') | passwd root >/dev/null 2>&1
# WiFi：仅在设备确实有无线时设置（HG5585F-CT 有，XG-040G-MD 无）
if uci -q get wireless.@wifi-device[0] >/dev/null; then
	uci -q set wireless.@wifi-device[0].disabled='0'
	uci -q set wireless.@wifi-iface[0].ssid='HG5585F-CT'
	uci -q set wireless.@wifi-iface[0].key='88888888'
	uci -q set wireless.@wifi-iface[0].encryption='psk2+ccmp'
	uci -q commit wireless
fi
exit 0
CUSTOM_EOF
	chmod +x ./files/etc/uci-defaults/99-custom-init
	echo "[CUSTOM-ONU2] uci-defaults 99-custom-init written"
fi
# === CUSTOM-ONU2 END ===
