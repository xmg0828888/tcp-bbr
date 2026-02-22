#!/bin/bash
# VPS 网络极限优化脚本 - 自动检测配置，发挥最大速度
# https://github.com/xmg0828888/tcp-bbr

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
[ "$(id -u)" != "0" ] && echo -e "${RED}请使用 root 运行${NC}" && exit 1

CORES=$(nproc)
MEM_MB=$(free -m | awk '/Mem:/{print $2}')
MEM_BYTES=$((MEM_MB * 1024 * 1024))
IFACE=$(ip route | awk '/default/{print $5}' | head -1)

show_info() {
    echo -e "${CYAN}╔══════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   VPS 网络极限优化脚本 v1.0      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════╝${NC}"
    echo -e "CPU: ${YELLOW}${CORES} 核${NC}  内存: ${YELLOW}${MEM_MB}MB${NC}  内核: ${YELLOW}$(uname -r)${NC}"
    echo -e "网卡: ${YELLOW}${IFACE}${NC}"
    local algo=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    local qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    echo -e "拥塞算法: ${YELLOW}${algo}${NC}  队列: ${YELLOW}${qdisc}${NC}"
    if [ "$algo" = "bbr" ]; then
        echo -e "BBR: ${GREEN}✓ 已开启${NC}"
    else
        echo -e "BBR: ${RED}✗ 未开启${NC}"
    fi
    echo ""
}

# 根据内存自动计算缓冲区大小
calc_buffers() {
    if [ $MEM_MB -le 512 ]; then
        RMEM_MAX=8388608; WMEM_MAX=8388608; NETDEV_BUDGET=300
        TCP_MEM="65536 131072 262144"; TCP_RMEM="4096 87380 4194304"; TCP_WMEM="4096 65536 4194304"
        BACKLOG=1000; SOMAXCONN=1024; CONNTRACK=16384
    elif [ $MEM_MB -le 2048 ]; then
        RMEM_MAX=16777216; WMEM_MAX=16777216; NETDEV_BUDGET=600
        TCP_MEM="131072 262144 524288"; TCP_RMEM="4096 87380 8388608"; TCP_WMEM="4096 65536 8388608"
        BACKLOG=2000; SOMAXCONN=2048; CONNTRACK=65536
    elif [ $MEM_MB -le 8192 ]; then
        RMEM_MAX=33554432; WMEM_MAX=33554432; NETDEV_BUDGET=1200
        TCP_MEM="262144 524288 1048576"; TCP_RMEM="4096 87380 16777216"; TCP_WMEM="4096 65536 16777216"
        BACKLOG=5000; SOMAXCONN=4096; CONNTRACK=131072
    else
        RMEM_MAX=67108864; WMEM_MAX=67108864; NETDEV_BUDGET=2400
        TCP_MEM="524288 1048576 2097152"; TCP_RMEM="4096 87380 33554432"; TCP_WMEM="4096 65536 33554432"
        BACKLOG=10000; SOMAXCONN=8192; CONNTRACK=262144
    fi
    FILE_MAX=$((MEM_MB * 256))
    [ $FILE_MAX -lt 65535 ] && FILE_MAX=65535
}

do_optimize() {
    calc_buffers
    echo -e "${GREEN}正在优化... (${MEM_MB}MB 内存方案)${NC}"

    local CONF="/etc/sysctl.d/99-network-optimize.conf"
    cat > "$CONF" << EOF
# === BBR 拥塞控制 ===
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# === 缓冲区 (基于 ${MEM_MB}MB 内存) ===
net.core.rmem_max = ${RMEM_MAX}
net.core.wmem_max = ${WMEM_MAX}
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.ipv4.tcp_rmem = ${TCP_RMEM}
net.ipv4.tcp_wmem = ${TCP_WMEM}
net.ipv4.tcp_mem = ${TCP_MEM}
net.ipv4.udp_mem = ${TCP_MEM}

# === 连接队列 ===
net.core.netdev_max_backlog = ${BACKLOG}
net.core.somaxconn = ${SOMAXCONN}
net.ipv4.tcp_max_syn_backlog = ${SOMAXCONN}

# === TCP 快速回收 ===
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_max_tw_buckets = 65535
net.ipv4.tcp_max_orphans = 32768

# === TCP 性能 ===
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_adv_win_scale = 2
net.core.netdev_budget = ${NETDEV_BUDGET}
net.core.netdev_budget_usecs = 8000

# === 文件描述符 ===
fs.file-max = ${FILE_MAX}
fs.nr_open = ${FILE_MAX}

# === 连接跟踪 ===
net.netfilter.nf_conntrack_max = ${CONNTRACK}

# === 其他 ===
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

    sysctl --system >/dev/null 2>&1

    # 设置文件描述符限制
    if ! grep -q "# network-optimize" /etc/security/limits.conf 2>/dev/null; then
        cat >> /etc/security/limits.conf << EOF
# network-optimize
* soft nofile ${FILE_MAX}
* hard nofile ${FILE_MAX}
root soft nofile ${FILE_MAX}
root hard nofile ${FILE_MAX}
EOF
    fi

    # 网卡队列优化
    if command -v ethtool &>/dev/null && [ -n "$IFACE" ]; then
        ethtool -G "$IFACE" rx 4096 tx 4096 2>/dev/null
        ethtool -K "$IFACE" tso on gso on gro on 2>/dev/null
    fi

    echo -e "${GREEN}✓ 优化完成！${NC}"
    echo ""
    show_result
}

show_result() {
    echo -e "${CYAN}=== 优化结果 ===${NC}"
    echo -e "BBR: ${GREEN}$(sysctl -n net.ipv4.tcp_congestion_control)${NC}"
    echo -e "队列: $(sysctl -n net.core.default_qdisc)"
    echo -e "TCP FastOpen: $(sysctl -n net.ipv4.tcp_fastopen)"
    echo -e "缓冲区: rmem_max=$(( $(sysctl -n net.core.rmem_max) /1024/1024 ))MB wmem_max=$(( $(sysctl -n net.core.wmem_max) /1024/1024 ))MB"
    echo -e "Backlog: $(sysctl -n net.core.netdev_max_backlog)"
    echo -e "文件描述符: $(sysctl -n fs.file-max)"
    echo -e "端口范围: $(sysctl -n net.ipv4.ip_local_port_range)"
    echo ""
    echo -e "${YELLOW}重启后永久生效，无需额外操作${NC}"
}

do_restore() {
    echo -e "${YELLOW}正在恢复默认...${NC}"
    rm -f /etc/sysctl.d/99-network-optimize.conf
    sysctl --system >/dev/null 2>&1
    echo -e "${GREEN}✓ 已恢复默认配置${NC}"
}

show_menu() {
    clear
    show_info
    echo "1. 一键优化 (BBR + 内核参数 + 缓冲区)"
    echo "2. 查看当前状态"
    echo "3. 恢复默认配置"
    echo "0. 退出"
    echo ""
    read -p "请选择 [0-3]: " choice
    case "$choice" in
        1) do_optimize ;;
        2) show_result ;;
        3) do_restore ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选择${NC}" ;;
    esac
    echo ""; read -p "按回车继续..." && show_menu
}

case "${1:-}" in
    optimize|enable) do_optimize ;;
    restore|disable) do_restore ;;
    status) show_info; show_result ;;
    *) show_menu ;;
esac
