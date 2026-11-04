#!/bin/bash
# ==============================================================================
# zk-daepon 私有扩展脚本  |  Scripts/PRIVATE.sh
# 由 Scripts/Packages.sh 第 139-141 行在末尾 source
# 执行时的当前目录是 wrt/package/，UPDATE_PACKAGE 函数此时已可直接调用
#
# UPDATE_PACKAGE "包名" "作者/仓库" "分支" ["pkg"|"name"] ["额外清理名列表"]
#   pkg  = 从大杂烩仓库里只提取该包名的目录（kenzok8/small-package、OpenClash 用）
#   name = 把 clone 下来的仓库重命名
#   第5参 = 额外要删除的旧包目录名，避免同名包冲突导致 coremark 之类的报错
#
# ⚠️ 重复拉取 Packages.sh 已启用的包会导致 git clone 因目录已存在而失败，
#    整个 workflow 会直接挂掉。下面这些不要再写一遍：
#    argon / aurora / aurora-config / openclash / ddns-go / qmodem / viking /
#    luci-app-airoha-npu / luci-app-lucky / quickstart / luci-app-istorex /
#    luci-app-store / luci-lib-taskd / luci-lib-xterm / taskd
# ==============================================================================

# ------------------------------------------------------------------------------
# 本次需求：OpenClash + QModem + USB 模组驱动
#
# 结论：这个文件不需要任何实际改动，保持空逻辑即可。
#   - OpenClash 源码：Packages.sh:60 已拉 vernesong/OpenClash(dev)
#   - QModem 源码：  Packages.sh:77 已拉 FUjr/QModem(main)
#   - USB 驱动：    内核自带 kmod，来自 package/kernel/linux/modules/usb.mk，
#                   只需在 Config/PRIVATE.txt 里置 y，不需要 clone 任何仓库
#
# QModem 的 clone 位置是 package/QModem/，其 luci Makefile 里
# `include ../../version.mk` 正好指到仓库根的 version.mk，
# 且 OpenWrt scan.mk 会递归扫描 package/*/*/*/Makefile，
# 所以 qmodem / luci-app-qmodem-next 等包能被 defconfig 发现，无需转成 feed。
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# 兜底（默认注释）：仅当 TEST=true 后在 Config-*.txt 里搜不到 qmodem 时启用
# 作用：把 QModem 的子包目录摊平到 package/ 顶层，强制被扫描到
# ⚠️ 会连带引入 driver/ 下多个厂商驱动包，可能增大固件，非必要不启用
# ------------------------------------------------------------------------------
# if [ -d "./QModem" ]; then
#   for D in ./QModem/application/* ./QModem/luci/*; do
#     [ -d "$D" ] && cp -rf "$D" ./
#   done
#   echo "QModem packages flattened into package/ for scan.mk"
# fi

# ------------------------------------------------------------------------------
# 兜底 B（默认注释）：QModem 的 QMI 驱动选择
#
# application/qmodem/Makefile 的 choice 里写的是：
#   default PACKAGE_qmodem_INCLUDE_vendor-qmi-wwan
# 即默认拉入厂商驱动 kmod-qmi_wwan_q / _f / _s（driver/ 目录下的第三方
# 内核模块）。在 6.18.55 内核上这些源码模块可能编译失败。
# 内核自带通用驱动 kmod-usb-net-qmi-wwan 已在 PRIVATE.txt 的 C3 启用，
# 所以遇到厂商驱动报错时，取消下面这段注释，把默认改成 generic 即可：
# ------------------------------------------------------------------------------
# if [ -f "./QModem/application/qmodem/Makefile" ]; then
#   sed -i 's/default PACKAGE_qmodem_INCLUDE_vendor-qmi-wwan/default PACKAGE_qmodem_INCLUDE_generic-qmi-wwan/' ./QModem/application/qmodem/Makefile
#   echo "QModem: default QMI driver switched to generic kernel qmi_wwan"
# fi

# ------------------------------------------------------------------------------
# 厂商驱动（按需）：QModem 仓库 driver/ 下自带 quectel_QMI_WWAN、
# quectel_MHI、fibocom_QMI_WWAN、simcom_QMI_WWAN 等内核模块包。
# 包名以各目录 Makefile 的 PKG_NAME 为准，先在 TEST 的 Config-*.txt 里
# 搜到确切符号，再回 Config/PRIVATE.txt 启用，不要凭目录名猜。
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# 备用：其它第三方插件模板，按需取消注释（取消后记得回 PRIVATE.txt 置 y）
# ------------------------------------------------------------------------------
#UPDATE_PACKAGE "passwall"  "Openwrt-Passwall/openwrt-passwall"  "main" "pkg"
#UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"
#UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy"                "main"
#UPDATE_PACKAGE "mosdns"    "sbwml/luci-app-mosdns"              "v5" "" "v2dat"
#UPDATE_PACKAGE "包名" "作者/仓库" "main" "" "需要一并清理的旧包名"

echo "PRIVATE.sh loaded: OpenClash / QModem sources come from Packages.sh, USB drivers are kernel kmods."
