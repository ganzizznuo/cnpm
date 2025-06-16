# ==================================================================
# 基础镜像: 使用官方的 Nginx Proxy Manager 镜像
# ==================================================================
FROM jc21/nginx-proxy-manager:latest

# 设置 DEBIAN_FRONTEND 为 noninteractive，避免在安装过程中出现交互式提示
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
# 设置默认的 root 密码。可以在容器运行时通过 -e ROOT_PASSWORD=your_password 来覆盖
ENV ROOT_PASSWORD=admin123

# ==================================================================
# 步骤 1 & 2: 安装基础工具和语言环境
# ==================================================================
RUN apt-get update && \
    # 安装添加 Node.js 源所需的前置依赖
    apt-get install -y ca-certificates curl gnupg && \
    # 为 APT 创建存放 GPG 密钥的目录
    mkdir -p /etc/apt/keyrings && \
    # 下载 NodeSource 的 GPG 密钥并存放到指定位置
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    # 定义 Node.js 的主版本号
    NODE_MAJOR=20 && \
    # 添加 NodeSource 的 APT 源 (重要修复: 此处使用 bookworm 替换了原来的 nodistro)
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x bookworm main" | tee /etc/apt/sources.list.d/nodesource.list && \
    # 再次更新 APT 包列表以包含新的 Node.js 源
    apt-get update && \
    # 一次性安装所有需要的软件包，使用 --no-install-recommends 减少不必要的依赖
    apt-get install -y --no-install-recommends \
    # --- 基础工具 ---
    openssh-server \
    sudo \
    wget \
    busybox-suid \
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
    # --- 进程管理与计划任务 ---
    supervisor \
    cron \
    && \
    # 清理 APT 缓存以减小镜像体积
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
