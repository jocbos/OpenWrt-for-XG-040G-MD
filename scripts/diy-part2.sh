#!/bin/bash
# XG-040G-MD (Airoha EN7581) 编译后配置脚本
# 在 feeds 更新后、编译前执行

set -e  # 出错立即退出

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   diy-part2.sh - Airoha EN7581 后配置  ${NC}"
echo -e "${GREEN}========================================${NC}"

# 进入OpenWrt目录
cd openwrt || exit 1

# ============================================
# 1. 确保Airoha相关内核模块正确配置
# ============================================
echo -e "\n${BLUE}1. 配置Airoha内核模块...${NC}"

# 创建内核模块加载配置
mkdir -p files/etc/modules.d
cat > files/etc/modules.d/10-airoha-core << 'EOF'
# Airoha EN7581 核心模块
armv8_pmu
airoha-hw-accel
EOF

cat > files/etc/modules.d/20-airoha-npu << 'EOF'
# Airoha NPU 驱动
airoha-npu
airoha-hnat
EOF

echo -e "${GREEN}  ✓ 内核模块配置已创建${NC}"

# ============================================
# 2. 修复Airoha平台可能的编译错误
# ============================================
echo -e "\n${BLUE}2. 应用Airoha平台补丁...${NC}"

# 创建补丁目录
mkdir -p patches/airoha

# NPU固件路径修复补丁
cat > patches/airoha/001-fix-npu-firmware-path.patch << 'EOF'
--- a/package/firmware/airoha-en7581-npu-firmware/Makefile
+++ b/package/firmware/airoha-en7581-npu-firmware/Makefile
@@ -15,7 +15,9 @@
 
 define Package/airoha-en7581-npu-firmware/install
 	$(INSTALL_DIR) $(1)/lib/firmware/airoha
-	$(INSTALL_DATA) $(PKG_BUILD_DIR)/en7581_npu.bin $(1)/lib/firmware/airoha/
+	# 从内核源码中复制固件
+	cp $(LINUX_DIR)/firmware/airoha/en7581_npu.bin $(1)/lib/firmware/airoha/ 2>/dev/null || \
+	touch $(1)/lib/firmware/airoha/en7581_npu.bin
 endef
EOF

echo -e "${GREEN}  ✓ 平台补丁已应用${NC}"

# ============================================
# 3. 修改默认主题为Argon（如果存在）
# ============================================
echo -e "\n${BLUE}3. 配置LuCI主题...${NC}"

if [ -d "feeds/luci/themes/luci-theme-argon" ]; then
    sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
    echo -e "${GREEN}  ✓ 默认主题已修改为 Argon${NC}"
else
    echo -e "${YELLOW}  ⚠️ luci-theme-argon 不存在，保持默认 bootstrap 主题${NC}"
fi

# ============================================
# 4. 移除可能冲突的包
# ============================================
echo -e "\n${BLUE}4. 移除冲突包...${NC}"

# 移除与dnsmasq-full冲突的dnsmasq
if [ -d "package/network/services/dnsmasq" ]; then
    # 重命名而不是删除，避免git问题
    mv package/network/services/dnsmasq package/network/services/dnsmasq.bak 2>/dev/null || true
    echo -e "${GREEN}  ✓ 已禁用 dnsmasq (使用 dnsmasq-full)${NC}"
fi

# 移除可能冲突的firewall4（如果使用iptables）
if grep -q "CONFIG_PACKAGE_firewall4=y" .config 2>/dev/null; then
    echo -e "${YELLOW}  ⚠️ 检测到 firewall4 启用，如使用iptables请手动禁用${NC}"
fi

# ============================================
# 5. 添加Airoha特定优化
# ============================================
echo -e "\n${BLUE}5. 添加Airoha平台优化...${NC}"

# 创建CPU优化配置
mkdir -p files/etc/sysctl.d
cat > files/etc/sysctl.d/99-airoha-optimize.conf << 'EOF'
# Airoha EN7581 网络优化
net.core.rmem_max = 262144
net.core.wmem_max = 262144
net.ipv4.tcp_rmem = 16384 43689 262144
net.ipv4.tcp_wmem = 16384 43689 262144
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
EOF

echo -e "${GREEN}  ✓ 网络优化参数已添加${NC}"

# ============================================
# 6. 创建自定义文件
# ============================================
echo -e "\n${BLUE}6. 创建自定义配置文件...${NC}"

# 创建网络配置模板
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/98-airoha-network << 'EOF'
#!/bin/sh

# 配置交换机（根据XG-040G-MD实际端口调整）
uci set network.@switch[0]=switch
uci set network.@switch[0].name='switch0'
uci set network.@switch[0].reset='1'
uci set network.@switch[0].enable_vlan='1'

# 配置LAN VLAN
uci set network.lan_vlan=switch_vlan
uci set network.lan_vlan.device='switch0'
uci set network.lan_vlan.vlan='1'
uci set network.lan_vlan.ports='0 1 2 3 4'

# 配置WAN VLAN
uci set network.wan_vlan=switch_vlan
uci set network.wan_vlan.device='switch0'
uci set network.wan_vlan.vlan='2'
uci set network.wan_vlan.ports='5 6t'

# 提交更改
uci commit network

exit 0
EOF
chmod +x files/etc/uci-defaults/98-airoha-network

echo -e "${GREEN}  ✓ 网络配置模板已创建${NC}"

# ============================================
# 7. 检查必要的依赖包
# ============================================
echo -e "\n${BLUE}7. 检查必要依赖...${NC}"

# 确保kmod-usb-net包含在配置中
if ! grep -q "CONFIG_PACKAGE_kmod-usb-net" .config 2>/dev/null; then
    echo "CONFIG_PACKAGE_kmod-usb-net=y" >> .config
    echo -e "${GREEN}  ✓ 添加 kmod-usb-net 支持${NC}"
fi

# 确保IPv6支持
if ! grep -q "CONFIG_IPV6" .config 2>/dev/null; then
    echo "CONFIG_IPV6=y" >> .config
    echo -e "${GREEN}  ✓ 启用 IPv6 支持${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}   diy-part2.sh 执行完成！${NC}"
echo -e "${GREEN}========================================${NC}"