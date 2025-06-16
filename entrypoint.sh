#!/bin/bash
set -e

# ==================================================================
# 1. 配置 SSH
# ==================================================================
echo ">> Configuring SSH..."
# 从环境变量设置 root 密码
echo "root:${ROOT_PASSWORD}" | chpasswd
echo ">> Root password set."

# 如果 SSH 主机密钥不存在，则生成它们
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
    echo ">> SSH host keys generated."
fi
# 启动 SSH 服务到后台
/usr/sbin/sshd
echo ">> SSH service started in background."

# ==================================================================
# 2. 加载并启动 Cron
# ==================================================================
echo ">> Loading and starting Cron..."
# 清理旧任务
rm -f /etc/cron.d/*
# 检查并加载新任务
if [ -d "/data/cron" ] && [ "$(ls -A /data/cron)" ]; then
    cp -f /data/cron/* /etc/cron.d/
    chmod 0644 /etc/cron.d/*
    echo ">> Custom cron jobs loaded."
fi
# 启动 Cron 服务到后台
cron
echo ">> Cron service started in background."

# ==================================================================
# 3. 启动 FRPC
# ==================================================================
FRPC_PATH="/data/frpc/frpc"
FRPC_INI_PATH="/data/frpc/frpc.ini"

if [ -f "$FRPC_PATH" ] && [ -f "$FRPC_INI_PATH" ]; then
    echo ">> Found frpc, starting service..."
    # 确保可执行
    chmod +x "$FRPC_PATH"
    # 在后台启动 frpc，并将日志重定向（可选，但推荐）
    nohup "$FRPC_PATH" -c "$FRPC_INI_PATH" > /var/log/frpc.log 2>&1 &
    echo ">> FRPC service started in background."
else
    echo ">> FRPC not found in /data/frpc, skipping."
fi

# ==================================================================
# 4. 移交主进程 (最重要的一步)
# ==================================================================
echo ">> Handing over control to Nginx Proxy Manager..."
# 使用 exec 执行原始的 CMD，这样 /init 就会成为主进程
exec "$@"
