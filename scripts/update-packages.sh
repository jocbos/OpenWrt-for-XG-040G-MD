#!/bin/bash
# XG-040G-MD (Airoha EN7581) 第三方软件包安装脚本
# 基于成功编译模板优化

set -e  # 出错立即退出

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 函数：克隆或更新仓库
clone_or_update() {
    local repo_url=$1
    local dir_name=$2
    local branch=${3:-master}
    
    if [ ! -d "$dir_name" ]; then
        echo -e "${YELLOW}▶ 克隆 $dir_name...${NC}"
        git clone --depth 1 -b "$branch" "$repo_url" "$dir_name"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  ✓ $dir_name 克隆成功${NC}"
        else
            echo -e "${RED}  ✗ $dir_name 克隆失败${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}▶ 更新 $dir_name...${NC}"
        cd "$dir_name" && git pull && cd ..
        echo -e "${GREEN}  ✓ $dir_name 更新完成${NC}"
    fi
}

# 函数：创建目录和文件
create_file() {
    local file_path=$1
    local content=$2
    
    mkdir -p "$(dirname "$file_path")"
    echo "$content" > "$file_path"
    echo -e "${GREEN}  ✓ 创建文件: $file_path${NC}"
}

echo -e "\n${BLUE}1. 安装核心插件...${NC}"

# 1. HomeProxy (必需)
clone_or_update "https://github.com/immortalwrt/homeproxy.git" "homeproxy" "main"

# 2. SmartDNS (必需)
clone_or_update "https://github.com/pymumu/luci-app-smartdns.git" "luci-app-smartdns" "master"
clone_or_update "https://github.com/pymumu/openwrt-smartdns.git" "smartdns" "master"

# 3. 磁盘管理
clone_or_update "https://github.com/lisaac/luci-app-diskman.git" "luci-app-diskman" "master"

# 4. 温度监控
clone_or_update "https://github.com/gSpotx2f/luci-app-temp-status.git" "luci-app-temp-status" "master"

# 5. CPU状态
clone_or_update "https://github.com/gSpotx2f/luci-app-cpu-status.git" "luci-app-cpu-status" "master"

# 6. MWAN3 Helper (如果官方feeds没有)
clone_or_update "https://github.com/immortalwrt/luci.git" "temp-luci" "openwrt-23.05"
if [ -d "temp-luci" ]; then
    cp -rf temp-luci/applications/luci-app-mwan3helper . 2>/dev/null || true
    rm -rf temp-luci
fi

echo -e "\n${BLUE}2. 创建Airoha EN7581 NPU优化脚本...${NC}"

# 7. Airoha NPU 优化脚本
mkdir -p airoha-npu-utils/files/etc/init.d
create_file "airoha-npu-utils/files/etc/init.d/npu-optimize" '#!/bin/sh /etc/rc.common
# Airoha EN7581 NPU 优化脚本
# 开机自动优化NPU性能

START=98
STOP=20

USE_PROCD=0

start() {
    echo "启动 Airoha EN7581 NPU 优化..."
    
    # 等待系统完全启动
    sleep 3
    
    # 检查NPU设备是否存在
    if [ -d "/proc/airoha" ] || [ -d "/sys/class/airoha" ]; then
        echo "检测到Airoha NPU设备"
        
        # 启用NPU硬件加速
        if [ -f "/proc/airoha/npu/enable" ]; then
            echo 1 > /proc/airoha/npu/enable 2>/dev/null && echo "  ✓ NPU加速已启用"
        fi
        
        # 配置NPU CPU亲和性 (使用所有核心)
        if [ -f "/proc/airoha/npu/cpu_affinity" ]; then
            echo "0-3" > /proc/airoha/npu/cpu_affinity 2>/dev/null && echo "  ✓ NPU CPU亲和性已设置"
        fi
        
        # 启用硬件NAT
        if [ -f "/proc/airoha/hnat/enable" ]; then
            echo 1 > /proc/airoha/hnat/enable 2>/dev/null && echo "  ✓ 硬件NAT已启用"
        fi
        
        # 设置NPU为性能模式
        if [ -f "/proc/airoha/npu/mode" ]; then
            echo "performance" > /proc/airoha/npu/mode 2>/dev/null && echo "  ✓ NPU性能模式已启用"
        fi
        
        logger -t npu "Airoha EN7581 NPU 优化完成"
    else
        echo "⚠️ 未检测到Airoha NPU设备，检查驱动是否加载"
        lsmod | grep -i airoha || echo "未加载airoha驱动"
    fi
    
    # CPU性能调优
    echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
    
    echo "NPU优化脚本执行完成"
}

stop() {
    echo "停止 NPU 优化..."
    if [ -f "/proc/airoha/npu/enable" ]; then
        echo 0 > /proc/airoha/npu/enable 2>/dev/null
    fi
    echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
}'

chmod +x airoha-npu-utils/files/etc/init.d/npu-optimize

echo -e "\n${BLUE}3. 创建系统默认配置...${NC}"

# 8. 系统默认配置
mkdir -p default-settings/files/etc/uci-defaults
create_file "default-settings/files/etc/uci-defaults/99-airoha-settings" '#!/bin/sh

# XG-040G-MD 默认配置脚本
# 首次启动时执行

# 设置网络
uci set network.lan=interface
uci set network.lan.proto='\''static'\''
uci set network.lan.ipaddr='\''192.168.3.1'\''
uci set network.lan.netmask='\''255.255.255.0'\''
uci set network.lan.device='\''br-lan'\''

# 设置LAN口 (根据实际硬件调整)
uci set network.lan.ifname='\''lan1 lan2 lan3 lan4'\''
uci set network.lan.type='\''bridge'\''

# 设置WAN口
uci set network.wan=interface
uci set network.wan.proto='\''dhcp'\''
uci set network.wan.device='\''wan'\''

# 设置主机名
uci set system.@system[0].hostname='\''XG-040G-MD'\''
uci set system.@system[0].timezone='\''CST-8'\''
uci set system.@system[0].zonename='\''Asia/Shanghai'\''

# 设置NTP服务器
uci set system.ntp=timeserver
uci set system.ntp.enabled='\''1'\''
uci set system.ntp.server='\''ntp.aliyun.com'\'' '\''ntp.tencent.com'\'' '\''time1.google.com'\''

# 设置中文
uci set luci.main.lang='\''zh_cn'\''
uci set luci.main.mediaurlbase='\''/luci-static/bootstrap'\''

# 启用NPU
if uci show airoha >/dev/null 2>&1; then
    uci set airoha.npu=core
    uci set airoha.npu.enabled='\''1'\''
    uci set airoha.npu.mode='\''performance'\''
fi

# 提交更改
uci commit

# 创建常用目录
mkdir -p /mnt/sda1
mkdir -p /mnt/sdb1
mkdir -p /mnt/downloads
mkdir -p /etc/transmission

# 设置权限
chmod 777 /mnt/sda1 2>/dev/null || true
chmod 777 /mnt/sdb1 2>/dev/null || true
chmod 777 /mnt/downloads 2>/dev/null || true

exit 0'

chmod +x default-settings/files/etc/uci-defaults/99-airoha-settings

echo -e "\n${BLUE}4. 创建NPU固件包（备用）...${NC}"

# 9. NPU固件包 (如果官方没有)
mkdir -p airoha-firmware/Makefile
create_file "airoha-firmware/Makefile" 'include $(TOPDIR)/rules.mk

PKG_NAME:=airoha-en7581-npu-firmware
PKG_VERSION:=2024.01
PKG_RELEASE:=1

PKG_LICENSE:=Proprietary
PKG_MAINTAINER:=OpenWrt Community

include $(INCLUDE_DIR)/package.mk

define Package/airoha-en7581-npu-firmware
  SECTION:=firmware
  CATEGORY:=Firmware
  TITLE:=Airoha EN7581 NPU firmware
  DEPENDS:=@TARGET_airoha_an7581
  URL:=https://github.com/xiangtailiang/openwrt
endef

define Package/airoha-en7581-npu-firmware/description
  NPU firmware for Airoha EN7581 platform (XG-040G-MD)
  Required for hardware acceleration
endef

define Build/Compile
endef

define Package/airoha-en7581-npu-firmware/install
	$(INSTALL_DIR) $(1)/lib/firmware/airoha
	# 这里需要从你的成功编译环境中获取实际固件文件
	# 临时创建占位文件
	touch $(1)/lib/firmware/airoha/en7581_npu.bin
	touch $(1)/lib/firmware/airoha/en7581_npu_fw.bin
endef

$(eval $(call BuildPackage,airoha-en7581-npu-firmware))'

echo -e "\n${BLUE}5. 创建USB自动挂载脚本...${NC}"

# 10. USB自动挂载
mkdir -p usb-automount/files/etc/hotplug.d/block
create_file "usb-automount/files/etc/hotplug.d/block/10-automount" '#!/bin/sh

# USB设备自动挂载脚本

case "$ACTION" in
    add)
        for i in /sys/block/*/device; do
            if [ -f "$i/../vendor" ]; then
                device="$(basename "$(dirname "$(dirname "$i")")")"
                if [ ! -d "/mnt/$device" ]; then
                    mkdir -p "/mnt/$device"
                    mount "/dev/$device" "/mnt/$device" 2>/dev/null && \
                        logger "USB设备已自动挂载到 /mnt/$device"
                fi
            fi
        done
        ;;
    remove)
        logger "USB设备已移除"
        ;;
esac'

chmod +x usb-automount/files/etc/hotplug.d/block/10-automount

echo -e "\n${BLUE}6. 创建Transmission优化配置...${NC}"

# 11. Transmission优化
mkdir -p transmission-optimize/files/etc/transmission
create_file "transmission-optimize/files/etc/transmission/settings.json" '{
    "alt-speed-down": 50,
    "alt-speed-enabled": false,
    "alt-speed-time-begin": 540,
    "alt-speed-time-day": 127,
    "alt-speed-time-enabled": false,
    "alt-speed-time-end": 1020,
    "alt-speed-up": 50,
    "bind-address-ipv4": "0.0.0.0",
    "bind-address-ipv6": "::",
    "blocklist-enabled": false,
    "cache-size-mb": 4,
    "dht-enabled": true,
    "download-dir": "/mnt/sda1/transmission",
    "download-queue-enabled": true,
    "download-queue-size": 5,
    "encryption": 1,
    "idle-seeding-limit": 30,
    "idle-seeding-limit-enabled": false,
    "incomplete-dir": "/mnt/sda1/incomplete",
    "incomplete-dir-enabled": true,
    "lpd-enabled": true,
    "message-level": 2,
    "peer-congestion-algorithm": "",
    "peer-id-ttl-hours": 6,
    "peer-limit-global": 200,
    "peer-limit-per-torrent": 50,
    "peer-port": 51413,
    "peer-port-random-high": 65535,
    "peer-port-random-low": 49152,
    "peer-port-random-on-start": false,
    "peer-socket-tos": "default",
    "pex-enabled": true,
    "port-forwarding-enabled": true,
    "preallocation": 1,
    "prefetch-enabled": true,
    "queue-stalled-enabled": true,
    "queue-stalled-minutes": 30,
    "ratio-limit": 2,
    "ratio-limit-enabled": true,
    "rename-partial-files": true,
    "rpc-authentication-required": false,
    "rpc-bind-address": "0.0.0.0",
    "rpc-enabled": true,
    "rpc-host-whitelist": "",
    "rpc-host-whitelist-enabled": true,
    "rpc-password": "{656b6f6832303234cd5c1e0e9b1d9e1e9b1d9e1e",
    "rpc-port": 9091,
    "rpc-url": "/transmission/",
    "rpc-username": "admin",
    "rpc-whitelist": "192.168.*.*,127.0.0.1",
    "rpc-whitelist-enabled": true,
    "scrape-paused-torrents-enabled": true,
    "script-torrent-done-enabled": false,
    "script-torrent-done-filename": "",
    "seed-queue-enabled": false,
    "seed-queue-size": 10,
    "speed-limit-down": 100,
    "speed-limit-down-enabled": false,
    "speed-limit-up": 50,
    "speed-limit-up-enabled": false,
    "start-added-torrents": true,
    "trash-original-torrent-files": false,
    "umask": 18,
    "upload-slots-per-torrent": 14,
    "utp-enabled": true
}'

echo -e "\n${BLUE}7. 创建编译前检查脚本...${NC}"

# 12. 编译检查脚本
create_file "$WORKSPACE/scripts/check-config.sh" '#!/bin/bash
# 检查XG-040G-MD配置是否正确

echo "==================================="
echo "XG-040G-MD (Airoha EN7581) 配置检查"
echo "==================================="

check_config() {
    local config_file=$1
    
    if [ ! -f "$config_file" ]; then
        echo "❌ 配置文件不存在: $config_file"
        return 1
    fi
    
    echo "✅ 配置文件存在: $config_file"
    
    # 检查关键配置
    local required_configs=(
        "CONFIG_TARGET_airoha=y"
        "CONFIG_TARGET_airoha_an7581=y"
        "CONFIG_TARGET_airoha_an7581_DEVICE_bell_xg-040g-md=y"
        "CONFIG_PACKAGE_airoha-en7581-npu-firmware=y"
    )
    
    local missing=0
    for cfg in "${required_configs[@]}"; do
        if grep -q "^$cfg" "$config_file"; then
            echo "  ✓ $cfg"
        else
            echo "  ❌ $cfg (缺失)"
            missing=1
        fi
    done
    
    if [ $missing -eq 0 ]; then
        echo -e "\n✅ 所有Airoha必要配置都存在"
    else
        echo -e "\n⚠️ 部分必要配置缺失，编译可能失败"
    fi
}

check_config "$WORKSPACE/config/xg-040g-md.config"'

chmod +x "$WORKSPACE/scripts/check-config.sh"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Airoha EN7581 包安装脚本执行完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${BLUE}已安装/创建的组件：${NC}"
echo "  • HomeProxy (代理客户端)"
echo "  • SmartDNS (智能DNS)"
echo "  • 磁盘管理"
echo "  • 温度监控"
echo "  • CPU状态监控"
echo "  • Airoha NPU优化脚本"
echo "  • 系统默认配置"
echo "  • NPU固件包 (备用)"
echo "  • USB自动挂载"
echo "  • Transmission优化配置"
echo "  • 配置检查脚本"
echo -e "${GREEN}========================================${NC}"

# 运行配置检查
echo -e "\n${BLUE}运行配置检查...${NC}"
bash "$WORKSPACE/scripts/check-config.sh"
