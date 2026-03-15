#!/bin/bash
#
# Kiro CLI Auto-Installation Script for OpenClaw on AWS
# This script installs Kiro CLI for the ubuntu user
# Can be run manually or via cloud-init/systemd
#
# Usage:
#   sudo bash install-kiro.sh
#   OR
#   curl -fsSL https://raw.githubusercontent.com/.../install-kiro.sh | sudo bash
#

set -e

INSTALL_USER="ubuntu"
LOG_FILE="/var/log/kiro-install.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "======================================"
log "Kiro CLI Installation Script Starting"
log "======================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log "ERROR: This script must be run as root"
    exit 1
fi

# Check if ubuntu user exists
if ! id "$INSTALL_USER" &>/dev/null; then
    log "ERROR: User $INSTALL_USER does not exist"
    exit 1
fi

# Check if Node.js is installed for ubuntu user
log "Checking Node.js installation..."
if ! su - "$INSTALL_USER" -c "command -v node" &>/dev/null; then
    log "ERROR: Node.js not found for user $INSTALL_USER"
    log "OpenClaw should have installed Node.js. Please check the installation."
    exit 1
fi

NODE_VERSION=$(su - "$INSTALL_USER" -c "node --version" 2>/dev/null)
NPM_VERSION=$(su - "$INSTALL_USER" -c "npm --version" 2>/dev/null)
log "Node.js version: $NODE_VERSION"
log "npm version: $NPM_VERSION"

# Check if Kiro CLI is already installed
if su - "$INSTALL_USER" -c "command -v kiro-cli" &>/dev/null; then
    CURRENT_VERSION=$(su - "$INSTALL_USER" -c "kiro-cli --version" 2>/dev/null)
    log "Kiro CLI is already installed: $CURRENT_VERSION"
    log "To reinstall, uninstall first: npm uninstall -g kiro-cli"
    exit 0
fi

# Install Kiro CLI using the official installer
log "Installing Kiro CLI via official installer..."
su - "$INSTALL_USER" -c "curl -fsSL https://cli.kiro.dev/install | bash" 2>&1 | tee -a "$LOG_FILE"

# Wait a moment for installation to complete
sleep 2

# Verify installation
log "Verifying Kiro CLI installation..."
if su - "$INSTALL_USER" -c "command -v kiro-cli" &>/dev/null; then
    INSTALLED_VERSION=$(su - "$INSTALL_USER" -c "kiro-cli --version" 2>/dev/null)
    log "✅ Kiro CLI successfully installed: $INSTALLED_VERSION"
    
    # Show installation location
    KIRO_PATH=$(su - "$INSTALL_USER" -c "which kiro-cli" 2>/dev/null)
    log "Kiro CLI location: $KIRO_PATH"
    
    log "======================================"
    log "Installation completed successfully!"
    log "======================================"
    log ""
    log "To use Kiro CLI:"
    log "  su - $INSTALL_USER"
    log "  kiro-cli --help"
    log ""
    log "To authenticate (optional):"
    log "  kiro-cli login"
    
    exit 0
else
    log "❌ ERROR: Kiro CLI installation failed"
    log "Installation might have failed. Check the log above for errors."
    exit 1
fi
