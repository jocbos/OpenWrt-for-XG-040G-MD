#!/bin/bash
# XG-040G-MD (Airoha EN7581) 配置检查脚本
# 在编译前验证配置是否正确

set -e  # 出错立即退出

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   XG-040G-MD Airoha EN7581 配置检查  ${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查配置文件是否存在
CONFIG_FILE="config/xg-040g.config"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ 配置文件不存在: $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "\n${BLUE}1. 检查Airoha平台必要配置${NC}"

# 必要配置列表
REQUIRED_CONFIGS=(
    "CONFIG_TARGET_airoha=y"
    "CONFIG_TARGET_airoha_an7581=y"
    "CONFIG_TARGET_airoha_an7581_DEVICE_bell_xg-040g-md=y"
    "CONFIG_TARGET_ARCH_PACKAGES=\"aarch64_cortex-a53\""
    "CONFIG_PACKAGE_airoha-en7581-npu-firmware=y"
)

MISSING_COUNT=0
for cfg in "${REQUIRED_CONFIGS[@]}"; do
    # 提取配置名（等号前的部分）
    cfg_name=$(echo "$cfg" | cut -d'=' -f1)
    
    if grep -q "^$cfg_name" "$CONFIG_FILE"; then
        # 如果是带引号的配置（如ARCH_PACKAGES），需要特殊处理
        if echo "$cfg" | grep -q "\""; then
            if grep -q "^$cfg_name=" "$CONFIG_FILE" | grep -q "aarch64_cortex-a53"; then
                echo -e "${GREEN}  ✓ $cfg_name 配置正确${NC}"
            else
                echo -e "${RED}  ❌ $cfg_name 配置值不正确，应为 aarch64_cortex-a53${NC}"
                MISSING_COUNT=$((MISSING_COUNT + 1))
            fi
        else
            if grep -q "^$cfg" "$CONFIG_FILE"; then
                echo -e "${GREEN}  ✓ $cfg${NC}"
            else
                echo -e "${RED}  ❌ $cfg${NC}"
                MISSING_COUNT=$((MISSING_COUNT + 1))
            fi
        fi
    else
        echo -e "${RED}  ❌ $cfg_name 未配置${NC}"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done

if [ $MISSING_COUNT -eq 0 ]; then
    echo -e "${GREEN}  ✅ 所有Airoha必要配置都存在${NC}"
else
    echo -e "${RED}  ❌ 缺少 $MISSING_COUNT 个必要配置，编译可能失败${NC}"
fi

echo -e "\n${BLUE}2. 检查功能包配置${NC}"

# 功能包列表（根据你的需求）
FEATURE_PACKAGES=(
    "CONFIG_PACKAGE_luci=y"
    "CONFIG_PACKAGE_luci-i18n-base-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-mwan3=y"
    "CONFIG_PACKAGE_luci-app-smartdns=y"
    "CONFIG_PACKAGE_luci-app-homeproxy=y"
    "CONFIG_PACKAGE_luci-app-zerotier=y"
    "CONFIG_PACKAGE_luci-app-upnp=y"
    "CONFIG_PACKAGE_luci-app-transmission=y"
    "CONFIG_PACKAGE_luci-app-ksmbd=y"
    "CONFIG_PACKAGE_luci-app-vsftpd=y"
    "CONFIG_PACKAGE_luci-app-ttyd=y"
    "CONFIG_PACKAGE_luci-app-cpustats=y"
)

ENABLED_COUNT=0
for pkg in "${FEATURE_PACKAGES[@]}"; do
    if grep -q "^$pkg" "$CONFIG_FILE"; then
        echo -e "${GREEN}  ✓ $pkg${NC}"
        ENABLED_COUNT=$((ENABLED_COUNT + 1))
    else
        echo -e "${YELLOW}  ⚠️ $pkg 未启用（可选）${NC}"
    fi
done

echo -e "${GREEN}  已启用 $ENABLED_COUNT/${#FEATURE_PACKAGES[@]} 个功能包${NC}"

echo -e "\n${BLUE}3. 检查USB支持${NC}"

USB_CONFIGS=(
    "CONFIG_PACKAGE_kmod-usb3=y"
    "CONFIG_PACKAGE_kmod-usb-storage=y"
    "CONFIG_PACKAGE_kmod-fs-ext4=y"
    "CONFIG_PACKAGE_kmod-fs-exfat=y"
    "CONFIG_PACKAGE_kmod-fs-ntfs3=y"
)

USB_MISSING=0
for cfg in "${USB_CONFIGS[@]}"; do
    if grep -q "^$cfg" "$CONFIG_FILE"; then
        echo -e "${GREEN}  ✓ $cfg${NC}"
    else
        echo -e "${RED}  ❌ $cfg${NC}"
        USB_MISSING=$((USB_MISSING + 1))
    fi
done

if [ $USB_MISSING -eq 0 ]; then
    echo -e "${GREEN}  ✅ USB支持完整${NC}"
else
    echo -e "${RED}  ❌ USB支持不完整，缺少 $USB_MISSING 个配置${NC}"
fi

echo -e "\n${BLUE}4. 检查冲突包${NC}"

CONFLICT_PACKAGES=(
    "CONFIG_PACKAGE_dnsmasq=y"
)

for pkg in "${CONFLICT_PACKAGES[@]}"; do
    if grep -q "^$pkg" "$CONFIG_FILE"; then
        echo -e "${RED}  ❌ 冲突包 $pkg 已启用（应与 dnsmasq-full 冲突）${NC}"
    else
        echo -e "${GREEN}  ✓ $pkg 未启用${NC}"
    fi
done

echo -e "\n${BLUE}5. 统计信息${NC}"

# 统计总配置数
TOTAL_CONFIGS=$(grep -c "=y" "$CONFIG_FILE" 2>/dev/null || echo 0)
KERNEL_CONFIGS=$(grep -c "CONFIG_KERNEL" "$CONFIG_FILE" 2>/dev/null || echo 0)
PACKAGE_CONFIGS=$(grep -c "CONFIG_PACKAGE" "$CONFIG_FILE" 2>/dev/null || echo 0)

echo -e "${BLUE}  总配置项: $TOTAL_CONFIGS${NC}"
echo -e "${BLUE}  内核配置: $KERNEL_CONFIGS${NC}"
echo -e "${BLUE}  软件包配置: $PACKAGE_CONFIGS${NC}"

echo -e "\n${BLUE}6. 检查OpenWrt源码中的Airoha支持${NC}"

if [ -d "openwrt/target/linux/airoha" ]; then
    echo -e "${GREEN}  ✓ 找到 Airoha 目标目录${NC}"
    echo -e "${BLUE}  支持的设备:${NC}"
    ls -la openwrt/target/linux/airoha/image/ 2>/dev/null | grep -o "xg-040g.*" || echo "  未找到XG-040G-MD设备文件"
else
    echo -e "${YELLOW}  ⚠️ 未找到 Airoha 目标目录，可能需要添加补丁${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}           检查完成！${NC}"
echo -e "${GREEN}========================================${NC}"

# 总结
if [ $MISSING_COUNT -eq 0 ] && [ $USB_MISSING -eq 0 ]; then
    echo -e "${GREEN}✅ 配置检查通过！可以开始编译。${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️ 配置检查发现问题，建议修复后再编译。${NC}"
    exit 1
fi