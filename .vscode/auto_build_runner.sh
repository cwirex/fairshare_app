#!/bin/bash

# Auto-restarting build runner for FairShare development
# This script will continuously run build_runner watch and auto-restart on termination

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
AUTO_RESTART_DELAY=10  # seconds
MAX_RESTART_ATTEMPTS=999  # essentially unlimited

print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                   🚀 FairShare Auto Build Runner             ║"
    echo "║                     Code Generation Watcher                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_status() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️${NC} $1"
}

check_flutter_project() {
    if [ ! -f "pubspec.yaml" ]; then
        print_error "Not in a Flutter project directory. Please run from project root."
        exit 1
    fi
}

run_build_runner() {
    print_status "Starting dart run build_runner watch..."
    
    # Run build_runner watch and capture exit code
    dart run build_runner watch --delete-conflicting-outputs
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "Build runner completed successfully."
    elif [ $exit_code -eq 130 ]; then
        print_warning "Build runner interrupted by user (Ctrl+C)."
        return 130  # User interrupt - don't restart
    else
        print_error "Build runner exited with code: $exit_code"
    fi
    
    return $exit_code
}

wait_for_restart() {
    local mode="$1"
    
    case "$mode" in
        "auto")
            print_status "Auto-restarting in ${AUTO_RESTART_DELAY} seconds..."
            print_status "Press Ctrl+C to stop or Enter to restart immediately"
            
            # Countdown with ability to interrupt
            for (( i=$AUTO_RESTART_DELAY; i>0; i-- )); do
                echo -ne "\r${CYAN}[$(date '+%H:%M:%S')]${NC} Restarting in $i seconds... "
                
                # Check if user pressed Enter (non-blocking)
                read -t 1 -n 1 key
                if [ $? -eq 0 ]; then
                    echo -e "\n"
                    print_status "Restarting immediately..."
                    return 0
                fi
            done
            echo -e "\n"
            ;;
            
        "manual")
            echo -e "${YELLOW}"
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "║  Build runner has stopped. What would you like to do?        ║"
            echo "║                                                              ║"
            echo "║  Press ENTER to restart                                     ║"
            echo "║  Press Ctrl+C to exit                                       ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo -e "${NC}"
            
            read -p "Press Enter to restart..." key
            ;;
            
        *)
            print_error "Invalid restart mode: $mode"
            return 1
            ;;
    esac
    
    return 0
}

cleanup() {
    print_warning "Cleaning up and exiting..."
    # Kill any remaining dart processes
    pkill -f "build_runner" 2>/dev/null
    exit 0
}

main() {
    # Set up signal handlers
    trap cleanup SIGINT SIGTERM
    
    # Parse command line arguments
    local restart_mode="auto"
    
    case "$1" in
        "--manual"|"-m")
            restart_mode="manual"
            print_status "Manual restart mode enabled"
            ;;
        "--auto"|"-a"|"")
            restart_mode="auto"
            print_status "Auto restart mode enabled (${AUTO_RESTART_DELAY}s delay)"
            ;;
        "--help"|"-h")
            echo "FairShare Auto Build Runner"
            echo ""
            echo "Usage: $0 [mode]"
            echo ""
            echo "Modes:"
            echo "  --auto, -a    Auto-restart after ${AUTO_RESTART_DELAY} seconds (default)"
            echo "  --manual, -m  Wait for user input before restarting"
            echo "  --help, -h    Show this help message"
            echo ""
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    
    print_banner
    check_flutter_project
    
    local attempt=1
    
    while [ $attempt -le $MAX_RESTART_ATTEMPTS ]; do
        print_status "🔄 Attempt #$attempt"
        
        # Run build runner
        run_build_runner
        local exit_code=$?
        
        # Handle different exit codes
        case $exit_code in
            130)
                # User interrupt (Ctrl+C)
                print_warning "Build runner stopped by user. Exiting..."
                break
                ;;
            0)
                # Normal termination
                print_success "Build runner completed normally."
                ;;
            *)
                # Error or other exit code
                print_error "Build runner failed with exit code: $exit_code"
                ;;
        esac
        
        # Wait for restart or user input
        if ! wait_for_restart "$restart_mode"; then
            break
        fi
        
        attempt=$((attempt + 1))
        print_status "Restarting build runner..."
        echo -e "${BLUE}=================================${NC}"
    done
    
    print_success "Auto build runner session ended."
}

# Run main function with all arguments
main "$@"