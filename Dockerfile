# Dockerfile (不再使用 Supervisor 的最终版)

# ==================================================================
# 基础镜像: 使用官方的 Nginx Proxy Manager 镜像
# ==================================================================
FROM jc21/nginx-proxy-manager:latest

# ==================================================================
# 镜像元数据与环境变量
# ==================================================================
LABEL maintainer="Your Name <your.email@example.com>"
LABEL description="集成了SSH、Cron、FRPC、开发工具(Python, Node.js) 的 Nginx Proxy Manager."

ENV DEBIAN_FRONTEND=noninteractive
ENV ROOT_PASSWORD=admin123
ENV TZ=Asia/Shanghai
# ==================================================================
# 步骤 1 & 2: 安装基础工具和语言环境
# ==================================================================
# 修复 1: 阻止 dpkg 自动启动服务
RUN echo '#!/bin/sh' > /usr/sbin/policy-rc.d && echo 'exit 101' >> /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d

# 执行安装 (注意: 已移除 supervisor)
RUN apt-get update && \
    # 修复 2: 添加 dpkg 选项以避免配置文件冲突
    apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    --no-install-recommends \
    # --- 基础工具 ---
    openssh-server \
    sudo \
    wget \
    curl \
    busybox \
    nano \
    tar \
    gzip \
    unzip \
    sshpass \
    git \
    # --- 语言环境 ---
    python3 \
    python3-pip \
    nodejs \
    # --- 计划任务 ---
    cron \
    && \
    # 清理工作
    rm /usr/sbin/policy-rc.d && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ==================================================================
# 步骤 3 & 4: 配置 SSH 和 Cron
# ==================================================================
# 允许 root 用户通过密码登录
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 为 sshd 创建运行目录
RUN mkdir -p /run/sshd

# 创建存放自定义 cron 任务的目录
RUN mkdir -p /data/cron/
COPY cron/ /data/cron/

# ==================================================================
# 最后设置: 入口点、端口和默认命令
# ==================================================================
# 复制在容器启动时执行的入口点脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 暴露端口
EXPOSE 22 80 81 443

# 指定容器的入口点为我们的自定义脚本
ENTRYPOINT ["/entrypoint.sh"]

# 将默认命令改回基础镜像的 /init
CMD ["/init"]
