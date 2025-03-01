#!/bin/bash

# Check if Neovim is installed
if ! command -v nvim &>/dev/null; then
  echo "Neovim is not installed. Installing Neovim..."
  # Install Neovim for Debian/Ubuntu
  if [ -f /etc/debian_version ]; then
    sudo apt-get update
    sudo apt-get install -y neovim
  # Install Neovim for Arch Linux
  elif [ -f /etc/arch-release ]; then
    sudo pacman -S --noconfirm neovim
  else
    echo "Unsupported Linux distribution. Please install Neovim manually."
    exit 1
  fi
fi

# Install Maple Font Mono
MAPLE_FONT_PATH="/usr/local/share/fonts/Maple_Font_Mono"
if ! [ -d "$MAPLE_FONT_PATH" ]; then
  echo "Maple Font Mono is not installed. Installing Maple Font Mono..."
  if command -v brew &>/dev/null; then
    brew tap homebrew/cask-fonts
    brew install --cask font-maple-font-mono
  else
    echo "Homebrew is not installed. Please install Maple Font Mono manually."
    exit 1
  fi
fi

# Backup existing nvim config if it exists
if [ -d ~/.config/nvim ]; then
  echo "Backing up existing nvim config to ~/.config/nvim.bak..."
  mv ~/.config/nvim ~/.config/nvim.bak
fi

# Clone Neo-Valhalla repository
echo "Cloning Neo-Valhalla repository..."
mkdir -p ~/.config/nvim
git clone https://github.com/fadingrose/Neo-Valhalla.git ~/.config/nvim

echo "Neo-Valhalla installed successfully."
