#!/bin/bash

################################################################################
# Home Server Setup Suite - Main Installation Script
# 
# This script provides an interactive interface to deploy and configure
# multiple services on a Proxmox Virtual Environment host.
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

# Services for IT Company Server: business-focused infrastructure
declare -A SERVICES=(
    [myspeed]="MySpeed - Speed test application"
    [wikijs]="Wiki.js - Modern wiki platform"
)

declare -A SERVICE_DESCRIPTIONS=(
    [myspeed]="Speed testing tool for network diagnostics."
    [wikijs]="Modern, lightweight wiki platform for documentation."
)

declare -A SERVICE_COMMANDS=(
    [myspeed]='bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/myspeed.sh)"'
    [wikijs]='bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/wikijs.sh)"'
)

declare -a SELECTED_SERVICES=()

################################################################################
# Helper Functions
################################################################################

# Displays welcome banner with colored formatting
print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║         Home Server Setup Suite - Interactive Installer        ║"
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



# Uses whiptail to present an interactive checklist for service selection
interactive_service_selection() {
    # Build whiptail checklist dynamically from SERVICES array
    local checklist_args=("--title" "Select Services" \
                          "--checklist" \
                          "Use SPACE to select, ENTER to confirm" \
                          "20" "70" "10")
    
    # Add ALL option at the beginning
    checklist_args+=("ALL" "Select all services" "OFF")
    
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
        # If ALL is selected, add all services
        if [[ "$service" == "ALL" ]]; then
            for svc in "${!SERVICES[@]}"; do
                SELECTED_SERVICES+=("$svc")
            done
        else
            SELECTED_SERVICES+=("$service")
        fi
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

# Prints available services with their descriptions and numbering
show_service_menu() {
    # Service listing removed - only code essential functionality
    return 0
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
        
        # Execute service installation using the command from SERVICE_COMMANDS
        if eval "${SERVICE_COMMANDS[$service]}"; then
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
