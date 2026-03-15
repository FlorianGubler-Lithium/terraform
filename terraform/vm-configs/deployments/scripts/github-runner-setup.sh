#!/bin/bash
# GitHub Actions runner setup script
# Usage: ./github-runner-setup.sh <org> <token> [runner_name]
#
# Arguments:
# - org:        GitHub organization name (required)
# - token:      GitHub Actions runner registration token (required)
# - version:    GitHub Actions runner version to install (required)
# - group:      GitHub Actions runner group to join (optional, defaults to "Default")
# - runner_name: Custom runner name, defaults to github-runner-<hostname> (optional)

set -euo pipefail

# Source environment variables including proxy settings
if [ -f /etc/environment ]; then
    set -a
    source /etc/environment
    set +a
fi

# Parse arguments
if [ $# -lt 2 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: Insufficient arguments"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Usage: $0 <org> <token> <version> [runner_name]"
    exit 1
fi

GITHUB_ORG="$1"
GITHUB_TOKEN="$2"
GITHUB_RUNNER_VERSION="$3"
RUNNER_GROUP="${4:-Default}"
RUNNER_NAME="${5:-github-runner-$(hostname)}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Starting GitHub Actions runner setup"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Organization: $GITHUB_ORG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Runner name: $RUNNER_NAME"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Runner group: $RUNNER_GROUP"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Runner Version: $GITHUB_RUNNER_VERSION"

# Validate required arguments
if [ -z "$GITHUB_ORG" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: GitHub organization not provided"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: GitHub token not provided"
    exit 1
fi

if [ -z "$GITHUB_RUNNER_VERSION" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: GitHub runner version not provided"
    exit 1
fi

# Determine architecture
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
    amd64) DOWNLOAD_ARCH="x64" ;;
    arm64) DOWNLOAD_ARCH="arm64" ;;
    *) echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: Unsupported architecture: $ARCH"; exit 1 ;;
esac

DOWNLOAD_URL="https://github.com/actions/runner/releases/download/v${GITHUB_RUNNER_VERSION}/actions-runner-linux-${DOWNLOAD_ARCH}-${GITHUB_RUNNER_VERSION}.tar.gz"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Download URL: $DOWNLOAD_URL"

if ! curl -v -L -O "$DOWNLOAD_URL"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: Failed to download GitHub Actions runner from $DOWNLOAD_URL"
    exit 1
fi

# Verify downloaded file exists
RUNNER_FILE="actions-runner-linux-${DOWNLOAD_ARCH}-${GITHUB_RUNNER_VERSION}.tar.gz"
if [ ! -f "$RUNNER_FILE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: Downloaded file not found: $RUNNER_FILE"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Successfully downloaded GitHub Actions runner"

# Extract runner files
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Extracting runner files"
chown github-runner:github-runner "/home/github-runner/actions-runner-linux-${DOWNLOAD_ARCH}-${GITHUB_RUNNER_VERSION}.tar.gz"
su - github-runner -c "tar xzf actions-runner-linux-${DOWNLOAD_ARCH}-${GITHUB_RUNNER_VERSION}.tar.gz"
rm "actions-runner-linux-${DOWNLOAD_ARCH}-${GITHUB_RUNNER_VERSION}.tar.gz"

# Register the runner
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Registering runner with GitHub organization"
su - github-runner -c "cd /home/github-runner && ./config.sh --url 'https://github.com/${GITHUB_ORG}' --token '${GITHUB_TOKEN}' --name '${RUNNER_NAME}' --runnergroup '${RUNNER_GROUP}' --work '_work' --replace --unattended"

if [ $? -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: Failed to register runner"
    exit 1
fi

# Install and enable systemd service
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Installing systemd service"
su - github-runner -c 'cd /home/github-runner && ./svc.sh install'

# Start the service
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Starting systemd service"
sudo systemctl daemon-reload
sudo systemctl enable github-actions.runner
sudo systemctl start github-actions.runner

# Verify service is running
sleep 2
if sudo systemctl is-active --quiet github-actions.runner; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] GitHub Actions runner is running"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] WARNING: GitHub Actions runner service is not running"
    sudo systemctl status github-actions.runner
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] GitHub Actions runner setup completed successfully!"

