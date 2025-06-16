#!/bin/bash
set -e

# ==================================================================
# Step 4 (Runtime): Configure SSH
# ==================================================================
echo ">> Configuring SSH..."
# Set the root password from the environment variable
echo "root:${ROOT_PASSWORD}" | chpasswd
echo ">> Root password set."

# Generate SSH host keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
    echo ">> SSH host keys generated."
fi

# ==================================================================
# Step 5 (Runtime): Load Cron Jobs
# ==================================================================
echo ">> Loading cron jobs..."
# Clear any existing cron jobs in /etc/cron.d to avoid duplicates
rm -f /etc/cron.d/*

# Copy all job files from /data/cron to the system cron directory
if [ -d "/data/cron" ] && [ "$(ls -A /data/cron)" ]; then
    cp -f /data/cron/* /etc/cron.d/
    # Set correct permissions for cron files
    chmod 0644 /etc/cron.d/*
    echo ">> Cron jobs from /data/cron loaded."
else
    echo ">> No custom cron jobs found in /data/cron."
fi

# ==================================================================
# Execute the original command (CMD)
# ==================================================================
echo ">> Starting supervisor..."
exec "$@"
