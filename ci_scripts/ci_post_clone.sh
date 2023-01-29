#!/bin/zsh

set -e

script_dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
cd "$script_dir/.."
root_dir=$(pwd)

export PATH=$PATH":$root_dir/.tuist-bin"

defaults write com.apple.dt.Xcode IDEPackageOnlyUseVersionsFromResolvedFile -bool NO
defaults write com.apple.dt.Xcode IDEDisableAutomaticPackageResolution -bool NO

make
