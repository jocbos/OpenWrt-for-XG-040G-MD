#!/bin/bash
# XG-040G-MD (Airoha EN7581) 预配置脚本 - 简化版

set -e

echo "========================================"
echo "diy-part1.sh - 开始预配置"
echo "========================================"

# 创建必要的目录
mkdir -p files/etc/uci-defaults

# 添加软件源
cat >> feeds.conf.default <<EOF
src-git kenzo https://github.com/kenzok8/openwrt-packages.git;master
src-git small https://github.com/kenzok8/small.git;master
EOF

# 创建IP设置脚本
cat > files/etc/uci-defaults/99-ip-set << 'EOF'
#!/bin/sh
uci set network.lan.ipaddr='192.168.3.1'
uci commit network
exit 0
EOF

# 添加执行权限
chmod +x files/etc/uci-defaults/99-ip-set

echo "✅ 预配置完成"
echo "========================================"
