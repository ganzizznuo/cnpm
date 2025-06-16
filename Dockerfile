# ==================================================================
# Base Image: Use the official Nginx Proxy Manager image
# ==================================================================
FROM jc21/nginx-proxy-manager:latest

# ==================================================================
# Metadata and Environment Variables
# ==================================================================
LABEL maintainer="Your Name <your.email@example.com>"
LABEL description="Nginx Proxy Manager with SSH, Dev Tools (Python, Node.js, Go), Supervisor, and dynamic Cron."

# Set DEBIAN_FRONTEND to noninteractive to avoid prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
# Set the default root password. Can be overridden at runtime with -e ROOT_PASSWORD=your_password
ENV ROOT_PASSWORD=admin123

# ==================================================================
# Step 1 & 2: Install Base Tools & Language Environments
# ==================================================================
RUN apt-get update && \
    # Install Node.js (using NodeSource repository for a recent version)
    apt-get install -y ca-certificates curl gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    NODE_MAJOR=20 && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    # Install all required packages
    apt-get install -y --no-install-recommends \
    # --- Basic Tools ---
    openssh-server \
    sudo \
    wget \
    busybox \
    nano \
    tar \
    gzip \
    unzip \
    sshpass \
    git \
    # --- Language Runtimes ---
    python3 \
    python3-pip \
    nodejs \
    golang \
    # --- Process Managers & Schedulers ---
    supervisor \
    cron \
    && \
    # Clean up APT cache to reduce image size
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ==================================================================
# Step 3: Configure Supervisor
# ==================================================================
# Create supervisor log directory
RUN mkdir -p /var/log/supervisor

# Create the directory for custom supervisor configs
RUN mkdir -p /data/supervisor

# Copy our custom supervisor config files into the image
COPY supervisor/ /data/supervisor/

# Modify the main supervisor config to include all configs from our custom directory
RUN echo "\n[include]" >> /etc/supervisor/supervisord.conf && \
    echo "files = /data/supervisor/*.conf" >> /etc/supervisor/supervisord.conf

# ==================================================================
# Step 4: Configure SSH Server
# ==================================================================
# Permit root login with password
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Create the directory for SSH host keys
RUN mkdir -p /run/sshd

# ==================================================================
# Step 5: Configure Cron
# ==================================================================
# Create the directory for custom cron jobs
RUN mkdir -p /data/cron

# Copy a placeholder cron file to demonstrate functionality
COPY cron/ /data/cron/

# ==================================================================
# Final Setup: Entrypoint, Ports, and Command
# ==================================================================
# Copy the entrypoint script that will run on container start
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports:
# 22 for SSH
# 80, 443 for Nginx Proxy Manager public traffic
# 81 for Nginx Proxy Manager admin UI
EXPOSE 22 80 81 443

# Set the entrypoint to our custom script
ENTRYPOINT ["/entrypoint.sh"]

# The default command is to run supervisord in the foreground
# The "-n" flag prevents it from daemonizing
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf", "-n"]
