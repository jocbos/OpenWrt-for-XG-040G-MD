#!/bin/bash
# XG-040G-MD (Airoha EN7581) 第三方软件包安装脚本
# 最终修复版 - 使用正确的分支

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   XG-040G-MD Airoha EN7581 包安装脚本  ${NC}"
echo -e "${GREEN}========================================${NC}"

# 进入正确目录
cd "$(dirname "$0")/.." || exit 1
WORKSPACE=$PWD
echo -e "${BLUE}工作目录: $WORKSPACE${NC}"

# 创建第三方包目录
mkdir -p package/thirdparty
cd package/thirdparty || exit 1

# 函数：使用正确的分支克隆
clone_package() {
    local repo_url=$1
    local dir_name=$2
    local branch=$3
    
    if [ -d "$dir_name" ]; then
        echo -e "${YELLOW}▶ 更新 $dir_name...${NC}"
        cd "$dir_name" && git pull && cd ..
        return 0
    fi
    
    echo -e "${YELLOW}▶ 克隆 $dir_name (分支: $branch)...${NC}"
    if git clone --depth 1 -b "$branch" "$repo_url" "$dir_name"; then
        echo -e "${GREEN}  ✓ $dir_name 克隆成功${NC}"
        return 0
    else
        echo -e "${RED}  ✗ $dir_name 克隆失败${NC}"
        return 1
    fi
}

echo -e "\n${BLUE}1. 安装核心插件...${NC}"

# 1. HomeProxy - 使用 master 分支
clone_package "https://github.com/immortalwrt/homeproxy.git" "homeproxy" "master"

# 2. SmartDNS
clone_package "https://github.com/pymumu/luci-app-smartdns.git" "luci-app-smartdns" "master"
clone_package "https://github.com/pymumu/openwrt-smartdns.git" "smartdns" "master"

# 3. 磁盘管理
clone_package "https://github.com/lisaac/luci-app-diskman.git" "luci-app-diskman" "master"

# 4. 温度监控
clone_package "https://github.com/gSpotx2f/luci-app-temp-status.git" "luci-app-temp-status" "master"

# 5. CPU状态
clone_package "https://github.com/gSpotx2f/luci-app-cpu-status.git" "luci-app-cpu-status" "master"

# 6. 如果需要 PassWall (可选)
# clone_package "https://github.com/xiaorouji/openwrt-passwall.git" "luci-app-passwall" "main"

echo -e "\n${BLUE}2. 创建Airoha NPU优化脚本...${NC}"

mkdir -p airoha-npu-utils/files/etc/init.d
cat > airoha-npu-utils/files/etc/init.d/npu-optimize << 'EOF'
#!/bin/sh /etc/rc.common
# Airoha EN7581 NPU 优化脚本

START=98

start() {
    echo "启动 Airoha EN7581 NPU 优化..."
    
    # 启用NPU硬件加速
    echo 1 > /proc/airoha/npu/enable 2>/dev/null && echo "  ✓ NPU加速已启用"
    echo 1 > /proc/airoha/hnat/enable 2>/dev/null && echo "  ✓ 硬件NAT已启用"
    
    # CPU性能模式
    echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
    
    echo "NPU优化完成"
}
EOF
chmod +x airoha-npu-utils/files/etc/init.d/npu-optimize
echo -e "${GREEN}  ✓ NPU优化脚本创建成功${NC}"

echo -e "\n${BLUE}3. 创建系统默认配置...${NC}"

mkdir -p default-settings/files/etc/uci-defaults
cat > default-settings/files/etc/uci-defaults/99-airoha-settings << 'EOF'
#!/bin/sh

# 设置网络
uci set network.lan.ipaddr='192.168.3.1'
uci set network.lan.netmask='255.255.255.0'

# 设置主机名
uci set system.@system[0].hostname='XG-040G-MD'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'

# 设置中文
uci set luci.main.lang='zh_cn'

uci commit

# 创建挂载点
mkdir -p /mnt/sda1 /mnt/sdb1

exit 0
EOF
chmod +x default-settings/files/etc/uci-defaults/99-airoha-settings
echo -e "${GREEN}  ✓ 系统默认配置创建成功${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ 安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"

# 显示安装结果
echo -e "\n${BLUE}已安装的包：${NC}"
ls -1 | grep -E "homeproxy|smartdns|diskman|temp-status|cpu-status|airoha|default" | sed 's/^/  • /'
