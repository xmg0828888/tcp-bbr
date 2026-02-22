# ⚡ VPS 网络极限优化

自动检测 VPS 配置（CPU/内存/带宽），一键开启 BBR + 内核参数调优，发挥最大网络性能。

## 一键安装

```
curl -sL https://cdn.jsdelivr.net/gh/xmg0828888/tcp-bbr/bbr.sh -o bbr.sh && chmod +x bbr.sh && ./bbr.sh
```

## 优化内容

- **BBR 拥塞控制** — 替代 cubic，大幅提升吞吐量
- **TCP 缓冲区** — 根据内存自动计算最优值（512M/2G/8G/16G+ 四档）
- **TCP FastOpen** — 减少握手延迟
- **连接队列** — somaxconn / backlog 自动调大
- **TIME_WAIT 回收** — tw_reuse + fin_timeout 缩短
- **文件描述符** — 自动提升上限
- **网卡优化** — TSO/GSO/GRO 硬件卸载
- **MTU 探测** — 自动寻找最优 MTU

## 命令行模式

```bash
./bbr.sh optimize  # 一键优化
./bbr.sh status    # 查看状态
./bbr.sh restore   # 恢复默认
./bbr.sh           # 交互菜单
```

## 要求

- Linux 4.9+ 内核
- root 权限
