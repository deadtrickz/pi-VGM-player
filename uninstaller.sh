#!/bin/bash

# Check if the script is running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please try again with 'sudo'."
   exit 1
fi

# Stop the service
echo "Stopping the service..."
sudo systemctl stop music_player.service

# Disable the service
echo "Disabling the service..."
sudo systemctl disable music_player.service

# Remove the service file
echo "Removing the service file..."
sudo rm /etc/systemd/system/music_player.service

# Remove the udev rule
echo "Removing the udev rule..."
sudo rm /etc/udev/rules.d/99-music-player.rules

# Remove the user from sudoers file
echo "Removing 'music' user from sudoers file..."
sudo sed -i '/music ALL=NOPASSWD: \/usr\/bin\/mount/d' /etc/sudoers
sudo sed -i '/music ALL=NOPASSWD: \/usr\/bin\/umount/d' /etc/sudoers

# Remove the scripts
echo "Removing the scripts..."
sudo rm /usr/local/bin/vgmplay-pvgmp4f.py
sudo rm /usr/local/bin/mocp-pvgmp4f.py
sudo rm /usr/local/bin/pvgmp4f.sh

# Remove the log file and directory
echo "Removing log file and directory..."
sudo rm -r /var/log/music_player

# Remove the directory for floppy
echo "Removing directory for floppy..."
sudo rm -r /mnt/floppy

# Uninstall VGMPlay
echo "Uninstalling VGMPlay..."
cd ~/vgmplay-master/VGMPlay
sudo make uninstall
cd ~
sudo rm -rf vgmplay-master

# Remove 'music' user
echo "Removing 'music' user..."
sudo userdel -r music

# Reload the udev rules
echo "Reloading udev rules..."
sudo udevadm control --reload-rules
sleep 5

echo "Uninstallation completed successfully!"
exit 0
