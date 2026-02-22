#!/bin/bash
# XG-040G-MD (Airoha EN7581) 预配置脚本
# 增强版 - 自动处理重复源

set -e

echo "========================================"
echo "diy-part1.sh - XG-040G-MD Airoha 平台预配置"
echo "========================================"

# 创建必要的目录
echo "创建目录结构..."
mkdir -p files/etc/uci-defaults
mkdir -p files/etc/modules.d
mkdir -p files/etc/sysctl.d

# ========== 智能处理 feeds.conf.default ==========
echo "处理 feeds.conf.default..."

FEEDS_FILE="feeds.conf.default"

# 如果文件存在，先备份
if [ -f "$FEEDS_FILE" ]; then
    cp "$FEEDS_FILE" "$FEEDS_FILE.bak-$(date +%Y%m%d%H%M%S)"
    echo "✅ 已备份原文件"
fi

# 创建一个全新的 feeds.conf.default（清空）
> "$FEEDS_FILE"

# 写入基础源（确保没有重复）
cat > "$FEEDS_FILE" << 'EOF'
# OpenWrt 官方源
src-git packages https://github.com/openwrt/packages.git;openwrt-23.05
src-git luci https://github.com/openwrt/luci.git;openwrt-23.05
src-git routing https://github.com/openwrt/routing.git;openwrt-23.05
src-git telephony https://github.com/openwrt/telephony.git;openwrt-23.05

# ImmortalWrt 源
src-git immortal_luci https://github.com/immortalwrt/luci.git;openwrt-23.05
src-git immortal_packages https://github.com/immortalwrt/packages.git;openwrt-23.05

# kenzok8 插件源
src-git kenzok8_packages https://github.com/kenzok8/openwrt-packages.git;master
src-git kenzok8_small https://github.com/kenzok8/small.git;master

# 本地第三方包
src-link thirdparty package/thirdparty
EOF

echo "✅ 已创建新的 feeds.conf.default"
echo "------------------------"
cat "$FEEDS_FILE"
echo "------------------------"

# ========== 设置默认IP ==========
echo "设置默认IP 192.168.3.1..."
cat > files/etc/uci-defaults/99-ip-set << 'EOF'
#!/bin/sh
uci set network.lan.ipaddr='192.168.3.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network

uci set system.@system[0].hostname='XG-040G-MD'
uci commit system

exit 0
EOF

chmod +x files/etc/uci-defaults/99-ip-set

# 验证
if [ -f "files/etc/uci-defaults/99-ip-set" ]; then
    echo "✅ 99-ip-set 创建成功"
else
    echo "❌ 99-ip-set 创建失败"
    exit 1
fi

echo "========================================"
echo "预配置完成"
echo "========================================"
