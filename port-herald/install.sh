#!/bin/bash

# Port Herald Installation Script for Kali Linux
# This script sets up Port Herald and its dependencies

set -e

echo "=================================="
echo "  Port Herald Installation Script"
echo "=================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on Kali
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "kali" ]]; then
        echo -e "${YELLOW}Warning: This script is optimized for Kali Linux${NC}"
        echo "Continue anyway? (y/n)"
        read -r response
        if [[ "$response" != "y" ]]; then
            exit 0
        fi
    fi
fi

echo -e "${GREEN}[1/6] Checking system dependencies...${NC}"

# Check for required tools
if ! command -v nmap &> /dev/null; then
    echo -e "${YELLOW}Nmap not found. Installing...${NC}"
    sudo apt-get update
    sudo apt-get install -y nmap
else
    echo "✓ Nmap installed"
fi

if ! command -v masscan &> /dev/null; then
    echo -e "${YELLOW}Masscan not found. Installing (optional but recommended)...${NC}"
    sudo apt-get install -y masscan
else
    echo "✓ Masscan installed"
fi

if ! command -v cargo &> /dev/null; then
    echo -e "${YELLOW}Rust not found. Installing...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "✓ Rust/Cargo installed"
fi

echo ""
echo -e "${GREEN}[2/6] Checking Rust version...${NC}"
RUST_VERSION=$(rustc --version | awk '{print $2}')
echo "✓ Rust version: $RUST_VERSION"

echo ""
echo -e "${GREEN}[3/6] Building Port Herald (this may take a few minutes)...${NC}"
cargo build --release

if [ $? -eq 0 ]; then
    echo "✓ Build successful"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}[4/6] Setting up directories...${NC}"
mkdir -p "$HOME/.port-herald"
mkdir -p "$HOME/.port-herald/scans"

echo ""
echo -e "${GREEN}[5/6] Creating helper scripts...${NC}"

# Create a launch script
cat > "$HOME/.port-herald/launch.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$(dirname "$SCRIPT_DIR")"

if [ "$1" == "--help" ]; then
    echo "Port Herald - Network Scanning & Visualization"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --database PATH    Database file path (default: ~/.port-herald/port-herald.db)"
    echo "  --bind ADDRESS     Bind address (default: 127.0.0.1)"
    echo "  --port PORT        Server port (default: 8080)"
    echo "  --help             Show this help message"
    echo ""
    exit 0
fi

./target/release/port-herald \
    --database "$HOME/.port-herald/port-herald.db" \
    --bind 127.0.0.1 \
    --port 8080 \
    "$@"
EOF

chmod +x "$HOME/.port-herald/launch.sh"

# Create a systemd service file (optional)
cat > port-herald.service << EOF
[Unit]
Description=Port Herald Network Scanning Platform
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/target/release/port-herald --database $HOME/.port-herald/port-herald.db --bind 127.0.0.1 --port 8080
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Created launch script: $HOME/.port-herald/launch.sh"
echo "✓ Created systemd service file: port-herald.service"

echo ""
echo -e "${GREEN}[6/6] Installation complete!${NC}"
echo ""
echo "=================================="
echo "  🎉 Port Herald is ready to use!"
echo "=================================="
echo ""
echo "Quick Start:"
echo ""
echo "1. Launch Port Herald:"
echo "   ./target/release/port-herald"
echo ""
echo "   Or use the helper script:"
echo "   $HOME/.port-herald/launch.sh"
echo ""
echo "2. Open your browser to:"
echo "   http://127.0.0.1:8080"
echo ""
echo "3. Start scanning!"
echo ""
echo "Optional: Install as a system service"
echo "   sudo cp port-herald.service /etc/systemd/system/"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable port-herald"
echo "   sudo systemctl start port-herald"
echo ""
echo "For more information, see README.md"
echo ""
echo -e "${YELLOW}Note: Many Nmap scan types require root privileges.${NC}"
echo -e "${YELLOW}Run with sudo for full functionality.${NC}"
echo ""
