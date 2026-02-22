# TCP BBR 一键开启

一键开启/关闭 TCP BBR 加速，支持交互菜单和命令行模式。

## 一键安装

```
curl -sL https://cdn.jsdelivr.net/gh/xmg0828888/tcp-bbr@main/bbr.sh -o bbr.sh && chmod +x bbr.sh && ./bbr.sh
```

## 命令行模式

```bash
./bbr.sh enable   # 开启 BBR
./bbr.sh disable  # 关闭 BBR
./bbr.sh status   # 查看状态
./bbr.sh          # 交互菜单
```

## 要求

- Linux 4.9+ 内核
- root 权限
