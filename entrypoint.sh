#!/bin/bash
set -e

# ==================================================================
# 1. 启动 ZeroTier
# ==================================================================
echo ">> Starting ZeroTier service..."
zerotier-one -d
sleep 2

# ==================================================================
# 2. 自动加入 ZeroTier 网络
# ==================================================================
if [ -n "$ZEROTIER_NETWORK_ID" ]; then
    echo ">> Found ZeroTier Network ID: $ZEROTIER_NETWORK_ID"
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
# 3. [新增] 配置 Moon 服务器
# ==================================================================
# 检查是否设置了 IS_MOON_SERVER 环境变量
if [ "$IS_MOON_SERVER" = "true" ]; then
    echo ">> Moon server mode enabled."
    # 检查 MOON_PUBLIC_IP 是否设置，这是必需的
    if [ -z "$MOON_PUBLIC_IP" ]; then
        echo ">> ERROR: IS_MOON_SERVER is true, but MOON_PUBLIC_IP is not set. Cannot configure moon."
    else
        MOON_CONFIG_FILE="/data/zerotier/moon.json"
        # 仅在 moon.json 文件不存在时才生成，避免重复操作
        if [ ! -f "$MOON_CONFIG_FILE" ]; then
            echo ">> Generating moon configuration for public IP: $MOON_PUBLIC_IP..."
            # 进入 ZeroTier 的工作目录
            cd /var/lib/zerotier-one
            # 1. 生成 moon 模板
            zerotier-idtool initmoon identity.public > moon.json
            # 2. 使用 sed 命令将公网 IP 插入到模板中
            sed -i 's/\"stableEndpoints\": \[\]/\"stableEndpoints\": \[ \"'${MOON_PUBLIC_IP}'\/9993\" \]/' moon.json
            # 3. 生成签名过的 moon 配置文件
            zerotier-idtool genmoon moon.json
            # 4. 创建 moons.d 目录，让本机使用这个 moon 配置
            mkdir -p moons.d
            cp *.moon moons.d/
            echo ">> Moon configuration generated and applied to this host."
            # 5. 将 moon.json 移动到挂载的数据目录，方便用户获取
            mv moon.json "$MOON_CONFIG_FILE"
            echo ">> Moon configuration file saved to $MOON_CONFIG_FILE for other clients to use."
        else
            echo ">> Moon configuration file already exists at $MOON_CONFIG_FILE, skipping generation."
            # 确保即使文件已存在，本机也加载了moon配置
            cd /var/lib/zerotier-one && mkdir -p moons.d && cp /data/zerotier/*.moon moons.d/
        fi
    fi
fi

# ==================================================================
# 4. 配置 SSH
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

# ... (cron 和 frpc 的部分保持不变) ...

# ==================================================================
# 5. 加载并启动 Cron
# ==================================================================
echo ">> Loading and starting Cron..."
rm -f /etc/cron.d/*; if [ -d "/data/cron" ] && [ "$(ls -A /data/cron)" ]; then cp -f /data/cron/* /etc/cron.d/ && chmod 0644 /etc/cron.d/* && echo ">> Custom cron jobs loaded."; fi; cron; echo ">> Cron service started in background."

# ==================================================================
# 6. 启动 FRPC
# ==================================================================
FRPC_PATH="/data/frpc/frpc"; FRPC_INI_PATH="/data/frpc/frpc.ini"; if [ -f "$FRPC_PATH" ] && [ -f "$FRPC_INI_PATH" ]; then echo ">> Found frpc, starting service..."; chmod +x "$FRPC_PATH"; nohup "$FRPC_PATH" -c "$FRPC_INI_PATH" > /var/log/frpc.log 2>&1 & echo ">> FRPC service started in background."; else echo ">> FRPC not found in /data/frpc, skipping."; fi

# ==================================================================
# 7. 移交主进程
# ==================================================================
echo ">> Handing over control to Nginx Proxy Manager..."
exec "$@"
