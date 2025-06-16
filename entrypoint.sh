#!/bin/bash
set -e

# ==================================================================
# 1. 启动 ZeroTier
# ==================================================================
echo ">> Starting ZeroTier service..."
# 在后台启动 ZeroTier 主服务
zerotier-one -d
# 等待几秒钟以确保服务完全初始化
sleep 2

# ==================================================================
# 2. 自动加入 ZeroTier 网络
# ==================================================================
# 检查 ZEROTIER_NETWORK_ID 环境变量是否被设置
if [ -n "$ZEROTIER_NETWORK_ID" ]; then
    echo ">> Found ZeroTier Network ID: $ZEROTIER_NETWORK_ID"
    # 检查是否已经加入了该网络，避免重复操作
    if ! zerotier-cli listnetworks -j | grep -q "$ZEROTIER_NETWORK_ID"; then
        echo ">> Not joined yet, attempting to join network..."
        zerotier-cli join "$ZEROTIER_NETWORK_ID"
    else
        echo ">> Already in the network, skipping join."
    fi
else
    echo ">> ZEROTIER_NETWORK_ID not set, skipping auto-join."
fi

# ==================================================================
# 3. 配置 SSH
# ==================================================================
echo ">> Configuring SSH..."
echo "root:${ROOT_PASSWORD}" | chpasswd
echo ">> Root password set."
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
    echo ">> SSH host keys generated."
fi
/usr/sbin/sshd
echo ">> SSH service started in background."

# ==================================================================
# 4. 加载并启动 Cron
# ==================================================================
echo ">> Loading and starting Cron..."
rm -f /etc/cron.d/*
if [ -d "/data/cron" ] && [ "$(ls -A /data/cron)" ]; then
    cp -f /data/cron/* /etc/cron.d/
    chmod 0644 /etc/cron.d/*
    echo ">> Custom cron jobs loaded."
fi
cron
echo ">> Cron service started in background."

# ==================================================================
# 5. 启动 FRPC
# ==================================================================
FRPC_PATH="/data/frpc/frpc"
FRPC_INI_PATH="/data/frpc/frpc.ini"
if [ -f "$FRPC_PATH" ] && [ -f "$FRPC_INI_PATH" ]; then
    echo ">> Found frpc, starting service..."
    chmod +x "$FRPC_PATH"
    nohup "$FRPC_PATH" -c "$FRPC_INI_PATH" > /var/log/frpc.log 2>&1 &
    echo ">> FRPC service started in background."
else
    echo ">> FRPC not found in /data/frpc, skipping."
fi

# ==================================================================
# 6. 移交主进程
# ==================================================================
echo ">> Handing over control to Nginx Proxy Manager..."
exec "$@"
