#!/bin/bash

# Check if the script is running with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo. Please try again with 'sudo'."
   exit 1
fi

# Stop and disable the music player service
echo "Stopping and disabling the music player service..."
sudo systemctl stop music_player.service
sudo systemctl disable music_player.service

# Remove the music player service file
echo "Removing the music player service file..."
sudo rm /etc/systemd/system/music_player.service

# Remove the udev rule
echo "Removing the udev rule..."
sudo rm /etc/udev/rules.d/99-music-player.rules

# Remove the music player script
echo "Removing the music player script..."
sudo rm /usr/local/bin/music_player.py

# Remove the player scripts
echo "Removing the player scripts..."
sudo rm /usr/local/bin/vgmplay-pvgmp4f.py
sudo rm /usr/local/bin/mocp-pvgmp4f.py

# Remove the log directory and log file
echo "Removing the log directory and log file..."
sudo rm -rf /var/log/music_player

# Remove the floppy directory
echo "Removing the floppy directory..."
sudo rm -rf /mnt/floppy

# Reload the udev rules
echo "Reloading the udev rules..."
sudo udevadm control --reload-rules

echo "Uninstallation completed successfully!"
exit 0
