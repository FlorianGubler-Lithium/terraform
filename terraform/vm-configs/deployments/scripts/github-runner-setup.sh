#!/bin/bash
# GitHub Actions runner setup script
# This script should be run with the following environment variables:
# - GITHUB_ORG: GitHub organization name
# - GITHUB_TOKEN: GitHub Actions runner registration token
# - RUNNER_NAME: (optional) Custom runner name, defaults to github-runner-<hostname>

set -euo pipefail

GITHUB_ORG="${GITHUB_ORG:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
RUNNER_NAME="${RUNNER_NAME:-github-runner-$(hostname)}"

echo "[github-runner-setup] Setting up GitHub Actions runner"
echo "[github-runner-setup] Organization: $GITHUB_ORG"
echo "[github-runner-setup] Runner name: $RUNNER_NAME"

# Validate required environment variables
if [ -z "$GITHUB_ORG" ]; then
    echo "[github-runner-setup] ERROR: GITHUB_ORG environment variable not set"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "[github-runner-setup] ERROR: GITHUB_TOKEN environment variable not set"
    exit 1
fi

# Create runner user if it doesn't exist
if id "github-runner" &>/dev/null; then
    echo "[github-runner-setup] Runner user already exists"
else
    useradd -m -s /bin/bash github-runner && echo "[github-runner-setup] Created github-runner user"
fi

# Change to runner home directory
cd /home/github-runner || { echo "[github-runner-setup] Error: Could not change to runner home directory"; exit 1; }

# Install prerequisites
echo "[github-runner-setup] Installing prerequisites"
apt-get update
apt-get install -y curl wget ca-certificates gnupg

# Determine architecture
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
    amd64) DOWNLOAD_ARCH="x64" ;;
    arm64) DOWNLOAD_ARCH="arm64" ;;
    *) echo "[github-runner-setup] Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Download GitHub Actions runner
echo "[github-runner-setup] Downloading GitHub Actions Runner"
LATEST_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases | grep 'tag_name' | sed -E 's/.*"v([^"]+)".*/\1/' | head -n 1)

if [ -z "$LATEST_VERSION" ]; then
    echo "[github-runner-setup] ERROR: Could not determine latest runner version"
    exit 1
fi

echo "[github-runner-setup] Latest version: v$LATEST_VERSION"

DOWNLOAD_URL="https://github.com/actions/runner/releases/download/v${LATEST_VERSION}/actions-runner-linux-${DOWNLOAD_ARCH}-${LATEST_VERSION}.tar.gz"
echo "[github-runner-setup] Download URL: $DOWNLOAD_URL"

curl -L -O "$DOWNLOAD_URL"

# Extract runner files
echo "[github-runner-setup] Extracting runner files"
chown github-runner:github-runner "/home/github-runner/actions-runner-linux-${DOWNLOAD_ARCH}-${LATEST_VERSION}.tar.gz"
su - github-runner -c "tar xzf actions-runner-linux-${DOWNLOAD_ARCH}-${LATEST_VERSION}.tar.gz"
rm "actions-runner-linux-${DOWNLOAD_ARCH}-${LATEST_VERSION}.tar.gz"

# Register the runner
echo "[github-runner-setup] Registering runner with GitHub organization"
su - github-runner -c "cd /home/github-runner && ./config.sh --url 'https://github.com/${GITHUB_ORG}' --token '${GITHUB_TOKEN}' --name '${RUNNER_NAME}' --runnergroup 'Default' --work '_work' --replace --unattended"

if [ $? -ne 0 ]; then
    echo "[github-runner-setup] ERROR: Failed to register runner"
    exit 1
fi

# Install and enable systemd service
echo "[github-runner-setup] Installing systemd service"
su - github-runner -c 'cd /home/github-runner && ./svc.sh install'

# Start the service
sudo systemctl daemon-reload
sudo systemctl enable github-actions.runner
sudo systemctl start github-actions.runner

# Verify service is running
sleep 2
if sudo systemctl is-active --quiet github-actions.runner; then
    echo "[github-runner-setup] GitHub Actions runner is running"
else
    echo "[github-runner-setup] WARNING: GitHub Actions runner service is not running"
    sudo systemctl status github-actions.runner
    exit 1
fi

echo "[github-runner-setup] GitHub Actions runner setup completed successfully!"

