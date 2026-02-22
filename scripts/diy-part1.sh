#!/bin/bash
# XG-040G-MD 编译前配置脚本
# 在 feeds update 之前执行

echo "运行 diy-part1.sh - XG-040G-MD Airoha 平台预配置"

# 添加自定义软件源
echo "src-git airoha_packages https://github.com/xiangtailiang/openwrt.git;main" >> feeds.conf.default

# 创建必要的目录
mkdir -p files/etc/config
mkdir -p files/etc/rc.d

# 设置默认IP地址
cat > files/etc/uci-defaults/99-ip-set << 'EOF'
#!/bin/sh
uci set network.lan.ipaddr='192.168.3.1'
uci commit network
exit 0
EOF
chmod +x files/etc/uci-defaults/99-ip-set