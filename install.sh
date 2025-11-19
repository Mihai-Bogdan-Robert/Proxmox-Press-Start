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

declare -A SERVICES=(
    [jellyfin]="Jellyfin - Open-source media system"
    [nextcloud]="Nextcloud - Self-hosted cloud storage"
)

declare -A SERVICE_DESCRIPTIONS=(
    [jellyfin]="Stream media (music, films, TV) from your own server. Open-source alternative to Plex."
    [nextcloud]="Self-hosted cloud storage with file sync and collaboration. Similar to Dropbox or Google Drive."
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

# Verifies script is running as root and Proxmox tools are installed
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
    
    echo -e "${GREEN}✓ Prerequisites met${RESET}"
}

# Prints available services with their descriptions and numbering
show_service_menu() {
    echo ""
    echo -e "${BLUE}Available Services:${RESET}"
    echo ""
    
    local i=1
    for service in "${!SERVICES[@]}"; do
        echo "  [$i] ${SERVICES[$service]}"
        i=$((i + 1))
    done
    
    echo ""
    echo -e "${YELLOW}Service Descriptions:${RESET}"
    echo ""
    
    for service in "${!SERVICE_DESCRIPTIONS[@]}"; do
        echo -e "${BLUE}• ${SERVICES[$service]}${RESET}"
        echo "  ${SERVICE_DESCRIPTIONS[$service]}"
        echo ""
    done
}

# Prompts user to select services using arrow keys and spacebar
interactive_service_selection() {
    echo -e "${BLUE}=== Service Selection ===${RESET}"
    show_service_menu
    
    local services_array=()
    for service in "${!SERVICES[@]}"; do
        services_array+=("$service")
    done
    
    local selected_indices=()
    local current_index=0
    
    while true; do
        # Clear previous output
        clear
        print_header
        
        echo -e "${YELLOW}Use arrow keys to navigate, spacebar to select, Enter to confirm:${RESET}"
        echo ""
        
        # Draw selection box
        echo "┌────────────────────────────────────────────────────────────┐"
        echo "│ Choose Services:                                           │"
        echo "├────────────────────────────────────────────────────────────┤"
        
        for i in "${!services_array[@]}"; do
            local service="${services_array[$i]}"
            local is_selected=false
            
            for idx in "${selected_indices[@]}"; do
                if [[ $idx -eq $i ]]; then
                    is_selected=true
                    break
                fi
            done
            
            if [[ $i -eq $current_index ]]; then
                if $is_selected; then
                    printf "│ ${GREEN}❯ [✓] %-50s${RESET}│\n" "${SERVICES[$service]}"
                else
                    printf "│ ${BLUE}❯ [ ] %-50s${RESET}│\n" "${SERVICES[$service]}"
                fi
            else
                if $is_selected; then
                    printf "│   ${GREEN}[✓] %-50s${RESET}│\n" "${SERVICES[$service]}"
                else
                    printf "│   [ ] %-50s│\n" "${SERVICES[$service]}"
                fi
            fi
        done
        
        echo "├────────────────────────────────────────────────────────────┤"
        printf "│ Selected: %-52s│\n" "${SELECTED_SERVICES[*]:-None}"
        echo "└────────────────────────────────────────────────────────────┘"
        echo ""
        
        # Read single key input
        local key
        read -rsn1 key 2>/dev/null || key=""
        
        case "$key" in
            $'\x1b')  # Arrow key pressed
                read -rsn2 key 2>/dev/null || key=""
                case "$key" in
                    '[A')  # Up arrow
                        ((current_index--))
                        if [[ $current_index -lt 0 ]]; then
                            current_index=$((${#services_array[@]} - 1))
                        fi
                        ;;
                    '[B')  # Down arrow
                        ((current_index++))
                        if [[ $current_index -ge ${#services_array[@]} ]]; then
                            current_index=0
                        fi
                        ;;
                esac
                ;;
            ' ')  # Spacebar
                local service="${services_array[$current_index]}"
                local is_selected=false
                local new_selected=()
                
                for idx in "${selected_indices[@]}"; do
                    if [[ $idx -eq $current_index ]]; then
                        is_selected=true
                    else
                        new_selected+=("$idx")
                    fi
                done
                
                if ! $is_selected; then
                    new_selected+=("$current_index")
                fi
                
                selected_indices=("${new_selected[@]}")
                SELECTED_SERVICES=()
                for idx in "${selected_indices[@]}"; do
                    SELECTED_SERVICES+=("${services_array[$idx]}")
                done
                ;;
            '')  # Enter key
                if [[ ${#SELECTED_SERVICES[@]} -eq 0 ]]; then
                    echo -e "${RED}Please select at least one service${RESET}"
                    sleep 1
                else
                    break
                fi
                ;;
        esac
    done
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
        
        local service_script="${SCRIPT_DIR}/scripts/services/${service}.sh"
        
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
    interactive_service_selection
    deploy_services
    
    echo ""
    echo -e "${BLUE}=== Installation Complete ===${RESET}"
    echo -e "${GREEN}All services have been deployed!${RESET}"
    echo ""
    echo -e "${YELLOW}Next steps:${RESET}"
    echo "  1. Access services through your network"
    echo "  2. Configure firewall rules as needed"
    echo ""
    echo "For help, see: README.md"
}

# Run main function
main "$@"
