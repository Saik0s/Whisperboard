#!/bin/zsh

script_dir="$(dirname "${BASH_SOURCE[0]}")"

cd $script_dir

# Check if gyb is available in the script folder and if not, download it
if [ ! -f "gyb" ]; then
    echo "gyb not found in script folder. Downloading..."
    wget -P . https://github.com/apple/swift/raw/main/utils/gyb
    wget -P . https://github.com/apple/swift/raw/main/utils/gyb.py
    chmod +x gyb
fi

# Generate secrets swift file using gyb from gyb file
./gyb --line-directive '' -o "../AppKit/Sources/App/Clients/Secrets.swift" "Secrets.swift.gyb"

