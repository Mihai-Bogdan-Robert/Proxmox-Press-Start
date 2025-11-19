#!/bin/bash

################################################################################
# Homer Service Installation Script
# 
# Wrapper for Proxmox Community Scripts Homer installer
# https://github.com/community-scripts/ProxmoxVE
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/scripts/utils/common.sh"
source "${SCRIPT_DIR}/scripts/utils/validation.sh"

SERVICE_NAME="homer"
COMMUNITY_SCRIPT_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/homer.sh"

# Parse arguments
DEPLOY_TYPE="${1:-lxc}"
STORAGE="${2:-local-lvm}"

# Validation
validate_proxmox_environment || exit 1
validate_storage "$STORAGE" || exit 1

################################################################################
# Deployment Functions
################################################################################

install_homer_lxc() {
    log_info "Downloading Homer installer from Proxmox Community Scripts..."
    
    # Download and execute the community script
    if bash <(curl -s "$COMMUNITY_SCRIPT_URL"); then
        log_success "Homer installed successfully"
        return 0
    else
        log_error "Failed to install Homer from community scripts"
        return 1
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    log_info "Starting Homer installation..."
    
    if [[ "$DEPLOY_TYPE" == "lxc" ]]; then
        install_homer_lxc || {
            log_error "LXC deployment failed"
            exit 1
        }
    elif [[ "$DEPLOY_TYPE" == "vm" ]]; then
        install_homer_vm || {
            log_error "VM deployment failed"
            exit 1
        }
    else
        log_error "Unknown deployment type: $DEPLOY_TYPE"
        exit 1
    fi
    
    log_success "Homer installation completed!"
}

main "$@"
