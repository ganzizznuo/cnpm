# ==================================================================
# 基础镜像: 使用官方的 Nginx Proxy Manager 镜像
# ==================================================================
FROM jc21/nginx-proxy-manager:latest

# ==================================================================
# 镜像元数据与环境变量
# ==================================================================
LABEL maintainer="Your Name <your.email@example.com>"
LABEL description="集成了SSH、开发工具(Python, Node.js)、Supervisor 和动态 Cron 的 Nginx Proxy Manager."

# 设置 DEBIAN_FRONTEND 为 noninteractive，避免在安装过程中出现大部分交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置默认的 root 密码。可以在容器运行时通过 -e ROOT_PASSWORD=your_password 来覆盖
ENV ROOT_PASSWORD=admin123

# ==================================================================
# 步骤 1 & 2: 安装基础工具和语言环境 (已应用所有修复)
# ==================================================================
# 修复 1: 创建临时的 policy-rc.d 文件，阻止 dpkg 在安装软件包后自动启动服务，避免与 s6-overlay 冲突。
RUN echo '#!/bin/sh' > /usr/sbin/policy-rc.d && \
    echo 'exit 101' >> /usr/sbin/policy-rc.d && \
    chmod +x /usr/sbin/policy-rc.d

# 执行安装
RUN apt-get update && \
    # 修复 2 (最终修复): 添加 dpkg 选项，强制对配置文件冲突使用默认行为（保留旧文件），从而完全避免交互式提示。
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
    # --- 语言环境 (从官方源安装) ---
    python3 \
    python3-pip \
    nodejs \
    # --- 进程管理与计划任务 ---
    supervisor \
    cron \
    && \
    # 清理工作: 删除临时的 policy-rc.d 文件和 APT 缓存
    rm /usr/sbin/policy-rc.d && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ==================================================================
# 步骤 3: 配置 Supervisor
# ==================================================================
# 创建 supervisor 的日志目录
RUN mkdir -p /var/log/supervisor

# 创建存放自定义 supervisor 配置的目录
RUN mkdir -p /data/supervisor/

# 将我们自定义的 supervisor 配置文件复制到镜像中
COPY supervisor/ /data/supervisor/

# 修改 supervisor 的主配置文件，让它加载我们自定义目录下的所有 .conf 文件
RUN echo "\n[include]" >> /etc/supervisor/supervisord.conf && \
    echo "files = /data/supervisor/*.conf" >> /etc/supervisor/supervisord.conf

# ==================================================================
# 步骤 4: 配置 SSH 服务
# ==================================================================
# 允许 root 用户通过密码登录
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 为 sshd 创建运行目录
RUN mkdir -p /run/sshd

# ==================================================================
# 步骤 5: 配置 Cron
# ==================================================================
# 创建存放自定义 cron 任务的目录
RUN mkdir -p /data/cron/

# 复制一个示例 cron 文件以演示功能
COPY cron/ /data/cron/

# ==================================================================
# 最后设置: 入口点、端口和默认命令
# ==================================================================
# 复制在容器启动时执行的入口点脚本
COPY entrypoint.sh /entrypoint.sh
# 赋予入口点脚本可执行权限
RUN chmod +x /entrypoint.sh

# 暴露端口:
# 22: SSH 服务
# 80, 443: Nginx Proxy Manager 的公共访问端口
# 81: Nginx Proxy Manager 的管理后台 UI 端口
EXPOSE 22 80 81 443

# 指定容器的入口点为我们的自定义脚本
ENTRYPOINT ["/entrypoint.sh"]

# 容器的默认命令是以前台模式运行 supervisord
# "-n" 参数可以防止它以守护进程模式运行，从而保持容器存活
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf", "-n"]
