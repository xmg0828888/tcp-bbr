#!/bin/bash
# TCP BBR 一键开启脚本
# https://github.com/xmg0828888/tcp-bbr

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'

check_root() { [ "$(id -u)" != "0" ] && echo -e "${RED}请使用 root 运行${NC}" && exit 1; }
check_os() { [ ! -f /etc/os-release ] && echo -e "${RED}不支持的系统${NC}" && exit 1; }

show_status() {
    echo -e "\n${GREEN}=== TCP BBR 状态 ===${NC}"
    local algo=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    local qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    local bbr_mod=$(lsmod | grep -c bbr)
    echo -e "拥塞算法: ${YELLOW}${algo}${NC}"
    echo -e "队列调度: ${YELLOW}${qdisc}${NC}"
    if [ "$algo" = "bbr" ] && [ "$bbr_mod" -gt 0 ]; then
        echo -e "BBR 状态: ${GREEN}✓ 已开启${NC}"
    else
        echo -e "BBR 状态: ${RED}✗ 未开启${NC}"
    fi
    echo ""
}

enable_bbr() {
    echo -e "${GREEN}正在开启 BBR...${NC}"
    
    # 写入 sysctl 配置
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    
    sysctl -p >/dev/null 2>&1
    
    # 验证
    local algo=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [ "$algo" = "bbr" ]; then
        echo -e "${GREEN}✓ BBR 开启成功！${NC}"
    else
        echo -e "${RED}✗ BBR 开启失败，内核可能不支持${NC}"
        echo -e "当前内核: $(uname -r)"
        echo -e "BBR 需要 Linux 4.9+ 内核"
    fi
}

disable_bbr() {
    echo -e "${YELLOW}正在关闭 BBR...${NC}"
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    echo "net.core.default_qdisc=pfifo_fast" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=cubic" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    echo -e "${GREEN}✓ 已恢复为 cubic${NC}"
}

show_menu() {
    clear
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}    TCP BBR 一键管理脚本${NC}"
    echo -e "${GREEN}================================${NC}"
    show_status
    echo "1. 开启 BBR"
    echo "2. 关闭 BBR"
    echo "3. 查看状态"
    echo "0. 退出"
    echo ""
    read -p "请选择 [0-3]: " choice
    case "$choice" in
        1) enable_bbr; show_status ;;
        2) disable_bbr; show_status ;;
        3) show_status ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选择${NC}" ;;
    esac
    read -p "按回车继续..." && show_menu
}

check_root
check_os

case "${1:-}" in
    enable)  enable_bbr; show_status ;;
    disable) disable_bbr; show_status ;;
    status)  show_status ;;
    *)       show_menu ;;
esac
