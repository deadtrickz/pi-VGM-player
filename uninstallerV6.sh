#!/bin/bash

# This script must be run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please try again with 'sudo'."
   exit 1
fi

# Stop and disable the service
echo "Stopping and disabling the service..."
systemctl stop pvgmp4f.service
systemctl disable pvgmp4f.service

# Remove the service
echo "Removing the service..."
rm /etc/systemd/system/pvgmp4f.service

# Remove the udev rule and reload udev rules
echo "Removing udev rule..."
rm /etc/udev/rules.d/99-music-player.rules
udevadm control --reload-rules

# Remove the sudoers entries
echo "Removing sudoers entries..."
sed -i '/^music ALL=NOPASSWD: \/usr\/bin\/mount/d' /etc/sudoers
sed -i '/^music ALL=NOPASSWD: \/usr\/bin\/umount/d' /etc/sudoers

# Remove the Python scripts
echo "Removing Python scripts..."
rm /usr/local/bin/vgmplay-pvgmp4f.py
rm /usr/local/bin/mocp-pvgmp4f.py
rm /usr/local/bin/pvgmp4f.py

# Remove VGMPlay
echo "Removing VGMPlay..."
cd ~/vgmplay-master/VGMPlay
make uninstall
make play_uninstall
cd ~
rm -r vgmplay-master
rm master.zip

# Remove the 'music' user
echo "Removing 'music' user..."
userdel -r music

# Remove the log file and directory
echo "Removing log file and directory..."
rm -r /var/log/pvgmp4f

# Remove the floppy mount point
echo "NOT Removing directory for floppy..."
#rm -r /mnt/floppy

echo "Uninstallation completed successfully!"
exit 0
