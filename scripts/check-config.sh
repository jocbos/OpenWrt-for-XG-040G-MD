#!/bin/bash
# XG-040G-MD (Airoha EN7581) 配置检查脚本
# 最终版 - 适配你的正确配置

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
CONFIG_FILE="config/040g.config"
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
    "CONFIG_PACKAGE_airoha-en7581-npu-firmware=y"
)

# 检查 ARCH_PACKAGES（单独处理）
ARCH_CONFIG="CONFIG_TARGET_ARCH_PACKAGES"

# 检查普通配置
for cfg in "${REQUIRED_CONFIGS[@]}"; do
    if grep -q "^$cfg" "$CONFIG_FILE"; then
        echo -e "${GREEN}  ✓ $cfg${NC}"
    else
        echo -e "${RED}  ❌ $cfg${NC}"
        echo -e "${RED}  ⚠️ 编译必须的配置缺失！${NC}"
        exit 1
    fi
done

# 检查 ARCH_PACKAGES（宽松检查）
if grep -q "^$ARCH_CONFIG" "$CONFIG_FILE"; then
    ARCH_LINE=$(grep "^$ARCH_CONFIG" "$CONFIG_FILE")
    echo -e "${GREEN}  ✓ $ARCH_CONFIG 已配置${NC}"
    
    # 提取值（去掉引号和空格）
    CURRENT_VALUE=$(echo "$ARCH_LINE" | cut -d'=' -f2 | tr -d '"' | tr -d ' ')
    if [[ "$CURRENT_VALUE" == *"aarch64_cortex-a53"* ]]; then
        echo -e "${GREEN}     值: $CURRENT_VALUE (正确)${NC}"
    else
        echo -e "${YELLOW}     警告: 当前值 $CURRENT_VALUE, 期望 aarch64_cortex-a53${NC}"
        echo -e "${YELLOW}     这个警告可以忽略，编译时会自动修正${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠️ $ARCH_CONFIG 未设置，编译时会自动添加${NC}"
fi

echo -e "\n${BLUE}2. 检查功能包配置${NC}"

# 主要功能包检查（可选，只显示不终止）
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

echo -e "${GREEN}  已启用 $ENABLED_COUNT/${#FEATURE_PACKAGES[@]} 个主要功能包${NC}"

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
        echo -e "${YELLOW}  ⚠️ $cfg 未启用（可选）${NC}"
        USB_MISSING=$((USB_MISSING + 1))
    fi
done

if [ $USB_MISSING -eq 0 ]; then
    echo -e "${GREEN}  ✅ USB支持完整${NC}"
else
    echo -e "${YELLOW}  ⚠️ USB支持不完整，缺少 $USB_MISSING 个配置${NC}"
fi

echo -e "\n${BLUE}4. 检查冲突包${NC}"

# 检查 dnsmasq 是否启用（与 dnsmasq-full 冲突）
if grep -q "^CONFIG_PACKAGE_dnsmasq=y" "$CONFIG_FILE"; then
    echo -e "${RED}  ❌ 冲突包 dnsmasq 已启用（应与 dnsmasq-full 冲突）${NC}"
    echo -e "${RED}     请在配置中禁用 dnsmasq${NC}"
    exit 1
else
    echo -e "${GREEN}  ✓ dnsmasq 已禁用（正确）${NC}"
fi

echo -e "\n${BLUE}5. 统计信息${NC}"

# 统计总配置数
TOTAL_CONFIGS=$(grep -c "=y" "$CONFIG_FILE" 2>/dev/null || echo 0)
KERNEL_CONFIGS=$(grep -c "CONFIG_KERNEL" "$CONFIG_FILE" 2>/dev/null || echo 0)
PACKAGE_CONFIGS=$(grep -c "CONFIG_PACKAGE" "$CONFIG_FILE" 2>/dev/null || echo 0)

echo -e "${BLUE}  总配置项: $TOTAL_CONFIGS${NC}"
echo -e "${BLUE}  内核配置: $KERNEL_CONFIGS${NC}"
echo -e "${BLUE}  软件包配置: $PACKAGE_CONFIGS${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}           检查完成！${NC}"
echo -e "${GREEN}========================================${NC}"

# 最终结果 - 只要必要配置存在就通过
echo -e "${GREEN}✅ 配置检查通过！可以开始编译。${NC}"
exit 0
