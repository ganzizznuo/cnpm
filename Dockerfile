# Dockerfile (已将 ZeroTier 数据目录链接到 /data/zerotier)

# ==================================================================
# 基础镜像: 使用官方的 Nginx Proxy Manager 镜像
# ==================================================================
FROM jc21/nginx-proxy-manager:latest

# ==================================================================
# 镜像元数据与环境变量
# ==================================================================
LABEL maintainer="Your Name <your.email@example.com>"
LABEL description="集成了SSH、Cron、FRPC、ZeroTier、开发工具(Python, Node.js) 的 Nginx Proxy Manager."

ENV DEBIAN_FRONTEND=noninteractive
ENV ROOT_PASSWORD=admin123
ENV ZEROTIER_NETWORK_ID=""
ENV TZ=Asia/Shanghai
# ==================================================================
# 步骤 1 & 2: 安装基础工具和语言环境
# ==================================================================
# 修复 1: 阻止 dpkg 自动启动服务
RUN echo '#!/bin/sh' > /usr/sbin/policy-rc.d && echo 'exit 101' >> /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d

# 执行安装 (添加了 gnupg 用于 ZeroTier 安装)
RUN apt-get update && \
    # 修复 2: 添加 dpkg 选项以避免配置文件冲突
    apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    --no-install-recommends \
    # --- 基础工具 ---
    openssh-server sudo wget curl gnupg busybox nano tar gzip unzip sshpass git \
    # --- 语言环境 ---
    python3 python3-pip nodejs \
    # --- 计划任务 ---
    cron \
    && \
    # 安装 ZeroTier
    curl -s https://install.zerotier.com | bash && \
    # 清理工作
    rm /usr/sbin/policy-rc.d && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 新增步骤：将 ZeroTier 的数据目录链接到 /data/zerotier
# 1. 确保目标目录存在
# 2. 删除原始目录（如果存在）
# 3. 创建符号链接
RUN mkdir -p /data/zerotier && \
    rm -rf /var/lib/zerotier-one && \
    ln -s /data/zerotier /var/lib/zerotier-one

# ... (从这里往下，所有内容保持不变) ...

# ==================================================================
# 步骤 3 & 4: 配置 SSH 和 Cron
# ==================================================================
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN mkdir -p /run/sshd
RUN mkdir -p /data/cron/
COPY cron/ /data/cron/

# ==================================================================
# 最后设置: 入口点、端口和默认命令
# ==================================================================
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22 80 81 443

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/init"]
