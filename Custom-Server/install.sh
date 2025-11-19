#!/bin/bash

################################################################################
# Custom Server Setup - Interactive Installation Script
# 
# This script provides an interactive interface to deploy custom services
# on a Proxmox Virtual Environment host. Select from all available services
# to build your own setup.
#
# Usage: bash install.sh
################################################################################

set -eo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

################################################################################
# Service Configuration
################################################################################

# All available services - customize for your needs
declare -A SERVICES=(
    [jellyfin]="Jellyfin - Open-source media system"
    [nextcloud]="Nextcloud - Self-hosted cloud storage"
    [pihole]="Pi-hole - DNS-based ad blocking"
    [docker]="Docker - Container platform"
    [samba]="Samba - File server"
    [nginx]="Nginx - Web server and reverse proxy"
    [netdata]="Netdata - System monitoring"
    [syncthing]="Syncthing - File sync"
)

declare -A SERVICE_DESCRIPTIONS=(
    [jellyfin]="Stream media (music, films, TV) from your own server. Open-source alternative to Plex."
    [nextcloud]="Self-hosted cloud storage with file sync and collaboration."
    [pihole]="Network-wide ad blocker. Block ads and trackers at the DNS level."
    [docker]="Container platform for running containerized applications."
    [samba]="Share folders with Windows/macOS/Linux clients using SMB/CIFS."
    [nginx]="Reverse proxy, load balancer, and web server for hosting services."
    [netdata]="Monitor CPU, disk, memory, network in real-time with dashboards."
    [syncthing]="Sync files across multiple devices in real-time securely."
)

declare -a SELECTED_SERVICES=()

################################################################################
# Helper Functions
################################################################################

# Displays welcome banner with colored formatting
print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║           Custom Server Setup - Interactive Installer          ║"
    echo "║                 Powered by Proxmox Virtual Environment         ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# Verifies script is running as root and required tools are installed
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${RESET}"
    
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root${RESET}"
        exit 1
    fi
    
    # Check if Proxmox is installed
    if ! command -v pvesm &> /dev/null; then
        echo -e "${RED}Error: Proxmox tools not found. Is this running on a Proxmox host?${RESET}"
        exit 1
    fi
    
    # Check if whiptail is installed for dialog
    if ! command -v whiptail &> /dev/null; then
        echo -e "${RED}Error: whiptail is not installed${RESET}"
        echo -e "${YELLOW}Install it with: apt-get install whiptail${RESET}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Prerequisites met${RESET}"
}

# Displays service information before selection
show_service_info() {
    clear
    print_header
    echo -e "${BLUE}=== Available Services ===${RESET}"
    echo ""
    
    for service in "${!SERVICE_DESCRIPTIONS[@]}"; do
        echo -e "${BLUE}• ${SERVICES[$service]}${RESET}"
        echo "  ${SERVICE_DESCRIPTIONS[$service]}"
        echo ""
    done
    
    sleep 2
}

# Uses whiptail to present an interactive checklist for service selection
interactive_service_selection() {
    # Build whiptail checklist dynamically from SERVICES array
    local checklist_args=("--title" "Select Services" \
                          "--checklist" \
                          "Use SPACE to select, ENTER to confirm" \
                          "24" "70" "12")
    
    for service in "${!SERVICES[@]}"; do
        checklist_args+=("$service" "${SERVICES[$service]}" "OFF")
    done
    
    # Show whiptail dialog
    local choices
    choices=$(whiptail "${checklist_args[@]}" 3>&1 1>&2 2>&3)
    local exitstatus=$?
    
    if [ $exitstatus -ne 0 ]; then
        echo -e "${RED}Installation cancelled.${RESET}"
        exit 0
    fi
    
    # Parse selected services
    SELECTED_SERVICES=()
    while IFS= read -r service; do
        SELECTED_SERVICES+=("$service")
    done <<< "$(echo "$choices" | tr ' ' '\n' | grep -v '^$')"
    
    if [[ ${#SELECTED_SERVICES[@]} -eq 0 ]]; then
        echo -e "${RED}No services selected. Please run the script again.${RESET}"
        exit 0
    fi
    
    # Show confirmation
    clear
    print_header
    echo -e "${GREEN}Selected services:${RESET}"
    for service in "${SELECTED_SERVICES[@]}"; do
        echo "  ✓ ${SERVICES[$service]}"
    done
    echo ""
    sleep 1
}

# Loops through selected services and executes their individual installation scripts
deploy_services() {
    echo ""
    echo -e "${BLUE}=== Starting Deployment ===${RESET}"
    
    local total=${#SELECTED_SERVICES[@]}
    local current=1
    
    for service in "${SELECTED_SERVICES[@]}"; do
        echo ""
        echo -e "${BLUE}[$current/$total] Installing ${SERVICES[$service]}...${RESET}"
        
        local service_script="$(cd "$SCRIPT_DIR" && cd .. && pwd)/scripts/services/${service}.sh"
        
        if [[ ! -f "$service_script" ]]; then
            echo -e "${RED}Error: Service script not found: $service_script${RESET}"
            ((current++))
            continue
        fi
        
        # Execute service installation (Proxmox Community Scripts handle all configuration)
        if bash "$service_script"; then
            echo -e "${GREEN}✓ ${SERVICES[$service]} installed successfully${RESET}"
        else
            echo -e "${RED}✗ Failed to install ${SERVICES[$service]}${RESET}"
        fi
        
        ((current++))
    done
}

# Main orchestration function - runs all steps in sequence
main() {
    print_header
    check_prerequisites
    show_service_info
    interactive_service_selection
    deploy_services
    
    echo ""
    echo -e "${BLUE}=== Installation Complete ===${RESET}"
    echo -e "${GREEN}All selected services have been deployed!${RESET}"
    echo ""
    echo -e "${YELLOW}Next steps:${RESET}"
    echo "  1. Access services through your network"
    echo "  2. Configure firewall rules as needed"
    echo "  3. Set up SSL certificates for web-facing services"
    echo ""
    echo "For help, see: README.md"
}

# Run main function
main "$@"
