#!/bin/bash
# GitHub Actions runner setup script
# Usage: ./github-runner-setup.sh <org> <pat> [runner_name]
#
# Arguments:
# - org:        GitHub organization name (required)
# - pat:        GitHub Personal Access Token with admin:org_self_hosted_runner scope (required)
# - version:    GitHub Actions runner version to install (required)
# - group:      GitHub Actions runner group to join (optional, defaults to "Default")
# - runner_name: Custom runner name, defaults to github-runner-<hostname> (optional)
#
# The script will:
# 1. Create the runner group if it doesn't exist
# 2. Generate a fresh runner registration token from the PAT
# 3. Register the runner with the generated token

set -euo pipefail

# Source environment variables including proxy settings
if [ -f /etc/environment ]; then
    set -a
    source /etc/environment
    set +a
fi

# Explicitly export proxy variables to ensure they're available to curl and other processes
export http_proxy
export https_proxy
export HTTP_PROXY
export HTTPS_PROXY
export no_proxy

# Debug: Show what proxy values are actually set
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Proxy configuration:"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] http_proxy=$http_proxy"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] https_proxy=$https_proxy"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] HTTP_PROXY=$HTTP_PROXY"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] HTTPS_PROXY=$HTTPS_PROXY"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] no_proxy=$no_proxy"

# Function to make GitHub API calls with error handling
github_api_call() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local url="https://api.github.com${endpoint}"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] GitHub API: $method $endpoint"

    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Authorization: token ${GITHUB_PAT}" \
            "$url")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Authorization: token ${GITHUB_PAT}" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$url")
    fi

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] HTTP Response: $http_code"

    if [[ "$http_code" =~ ^(200|201|204)$ ]]; then
        echo "$body"
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: API call failed with status $http_code"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Response: $body"
        return 1
    fi
}

# Function to create runner group if it doesn't exist
create_runner_group_if_needed() {
    local org="$1"
    local group="$2"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Checking if runner group '$group' exists"

    # List existing runner groups
    groups_response=$(github_api_call "GET" "/orgs/${org}/actions/runner-groups" "" || true)

    if echo "$groups_response" | grep -q "\"name\": \"${group}\""; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Runner group '$group' already exists"
        return 0
    fi

    # Group doesn't exist, create it
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Creating runner group '$group'"
    create_data="{\"name\": \"${group}\", \"visibility\": \"private\"}"

    if github_api_call "POST" "/orgs/${org}/actions/runner-groups" "$create_data"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Successfully created runner group '$group'"
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: Failed to create runner group '$group'"
        return 1
    fi
}

# Function to generate a runner registration token
get_registration_token() {
    local org="$1"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Generating runner registration token"

    token_response=$(github_api_call "POST" "/orgs/${org}/actions/runners/registration-token" "")

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Token response: $token_response"

    # Try multiple parsing methods for robustness
    token=$(echo "$token_response" | grep -o '"token":"[^"]*' | cut -d'"' -f4 2>/dev/null || true)

    # If that didn't work, try with jq if available
    if [ -z "$token" ] && command -v jq &> /dev/null; then
        token=$(echo "$token_response" | jq -r '.token' 2>/dev/null || true)
    fi

    # Last resort: try alternative grep pattern
    if [ -z "$token" ]; then
        token=$(echo "$token_response" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p' 2>/dev/null || true)
    fi

    if [ -z "$token" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: Failed to extract token from response"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Raw response was: $token_response"
        exit 1
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Successfully generated registration token (length: ${#token})"
    echo "REGISTRATION_TOKEN:$token"
}

# Parse arguments
if [ $# -lt 2 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: Insufficient arguments"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Usage: $0 <org> <pat> <version> [group] [runner_name]"
    exit 1
fi

GITHUB_ORG="$1"
GITHUB_PAT="$2"
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

if [ -z "$GITHUB_PAT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: GitHub Personal Access Token not provided"
    exit 1
fi

if [ -z "$GITHUB_RUNNER_VERSION" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: GitHub runner version not provided"
    exit 1
fi

# Validate token format
if [[ ! "$GITHUB_PAT" =~ ^ghp_ ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] WARNING: Token does not appear to be a Personal Access Token (should start with ghp_)"
fi

# Create runner group if needed
if ! create_runner_group_if_needed "$GITHUB_ORG" "$RUNNER_GROUP"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: Failed to create runner group"
    exit 1
fi

# Generate registration token
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Attempting to generate registration token from PAT..."
token_output=$(get_registration_token "$GITHUB_ORG")
GITHUB_TOKEN=$(echo "$token_output" | grep "^REGISTRATION_TOKEN:" | cut -d':' -f2)

if [ -z "$GITHUB_TOKEN" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: Failed to generate registration token"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Troubleshooting:"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup]   1. Verify PAT has 'admin:org_self_hosted_runner' scope (or 'Self-hosted runners: Read and write' for fine-grained)"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup]   2. Verify PAT has not expired"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup]   3. Verify organization name is correct: $GITHUB_ORG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup]   4. Check GitHub API status at https://www.githubstatus.com"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Successfully generated registration token"

# ...existing code...

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
RUNNER_INSTALL_DIR="/home/github-runner"
mkdir -p "$RUNNER_INSTALL_DIR"

# Extract runner files
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Extracting runner files"
tar -xzf "$RUNNER_FILE" -C "$RUNNER_INSTALL_DIR"

# Fix permissions for github-runner user
chown -R github-runner:github-runner "$RUNNER_INSTALL_DIR"

rm "$RUNNER_FILE"

# Install .NET dependencies (libicu and others)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Installing .NET dependencies"
if [ -f "$RUNNER_INSTALL_DIR/bin/installdependencies.sh" ]; then
    if ! "$RUNNER_INSTALL_DIR/bin/installdependencies.sh"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] WARNING: Failed to install .NET dependencies, continuing anyway"
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] WARNING: installdependencies.sh not found at $RUNNER_INSTALL_DIR/.bin/installdependencies.sh"
fi

# Register the runner
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Registering runner with GitHub organization"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] URL: https://github.com/${GITHUB_ORG}"

# Create a temporary log file for config.sh output
CONFIG_LOG=$(mktemp)
trap "rm -f $CONFIG_LOG" EXIT

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Executing config.sh (output logged to $CONFIG_LOG)"

# Run config.sh and capture output for debugging
if ! su - github-runner -c "cd $RUNNER_INSTALL_DIR && ./config.sh --url https://github.com/${GITHUB_ORG} --token ${GITHUB_TOKEN} --name ${RUNNER_NAME} --runnergroup ${RUNNER_GROUP}" 2>&1 | tee "$CONFIG_LOG"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] ERROR: Failed to register runner"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Config output:"
    cat "$CONFIG_LOG"
    exit 1
fi

# Install and enable systemd service
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github-runner-setup] Installing systemd service"
su - github-runner -c "cd $RUNNER_INSTALL_DIR && ./svc.sh install"

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