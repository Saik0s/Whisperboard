#!/bin/zsh

set -e

script_dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
cd "$script_dir/.."
root_dir=$(pwd)

export PATH=$PATH":$root_dir/.tuist-bin"

make
