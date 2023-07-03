#!/bin/bash

# Check if the script is running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please try again with 'sudo'."
   exit 1
fi

# Update package lists
echo "Updating package lists..."
sudo apt-get update
sleep 5

# Install Python3, MOC and Screen if not already installed
echo "Installing Python3, MOC, and Screen..."
sudo apt-get install -y python3 moc screen unzip libao-dev libdbus-1-dev moc-ffmpeg-plugin
sleep 5

# Create user 'music' with password PVGMP4F and add it to appropriate groups
echo "Creating 'music' user and adding it to 'audio' and 'floppy' groups..."
sudo useradd -m music
echo "music:PVGMP4F" | sudo chpasswd
sudo usermod -a -G audio,floppy music

# Download and install VGMPlay if not already installed
echo "Downloading and installing VGMPlay..."
cd ~
if [ ! -d "vgmplay-master" ]; then
    wget 'https://github.com/vgmrips/vgmplay/archive/refs/heads/master.zip'
    unzip master.zip
    cd vgmplay-master/VGMPlay
    make
    sudo make install
    sudo make play_install
    cd ~
fi
sleep 5

# Add the Python scripts
echo "Creating player scripts..."
cat << 'EOF' | sudo tee /usr/local/bin/vgmplay-pvgmp4f.py
#!/usr/bin/env python3

import argparse
import logging
import os
import subprocess
import time

SCREEN_SESSION_NAME = 'vgmplay_session'

def get_folder_content(folder_path):
    return [os.path.join(folder_path, f) for f in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, f))]

def handle_vgz(folder_path):
    content = get_folder_content(folder_path)
    vgz_files = [f for f in content if f.lower().endswith('.vgz')]
    if vgz_files:
        try:
            command = ['screen', '-dmS', SCREEN_SESSION_NAME, '/usr/local/bin/vgmplay'] + vgz_files
            subprocess.run(command, check=True)
        except Exception as e:
            logging.exception(f'Failed to start VGMPlay: {e}')

def main(folder_path):
    logging.basicConfig(level=logging.DEBUG)
    handle_vgz(folder_path)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='VGMPlay player for floppy disks.')
    parser.add_argument('folder_path', type=str, help='Path to the folder containing the music files.')
    args = parser.parse_args()
    main(args.folder_path)
EOF

cat << 'EOF' | sudo tee /usr/local/bin/mocp-pvgmp4f.py
#!/usr/bin/env python3

import time
import logging
import subprocess

SCREEN_SESSION_NAME = 'mocp_session'

def handle_m3u():
    command = "mocp -S -O AutoNext=yes -O Precache=no && mocp -o r,s,n && mocp -l /mnt/floppy/*"
    try:
        subprocess.call(command, shell=True)
    except Exception as e:
        logging.exception(f'Failed to start MOC player: {e}')

def main():
    logging.basicConfig(level=logging.DEBUG)
    handle_m3u()

if __name__ == '__main__':
    main()
EOF

# Make the player scripts executable and change the ownership
echo "Making player scripts executable and changing ownership..."
sudo chmod +x /usr/local/bin/vgmplay-pvgmp4f.py
sudo chmod +x /usr/local/bin/mocp-pvgmp4f.py
sudo chown music:music /usr/local/bin/vgmplay-pvgmp4f.py
sudo chown music:music /usr/local/bin/mocp-pvgmp4f.py

# Add the main script
echo "Creating the main service script..."
cat << 'EOF' | sudo tee /usr/local/bin/pvgmp4f.sh
#!/bin/bash

LOGFILE="/var/log/pvgmp4f/pvgmp4f.log"
FLOPPY_PATH="/mnt/floppy"

echo "$(date) - Script started" | tee -a $LOGFILE

while true; do
    if [ -b /dev/sda ]; then
        if ! grep -qs "$FLOPPY_PATH" /proc/mounts; then
            echo "$(date) - Mounting floppy" | tee -a $LOGFILE
            sudo mount -t vfat -o ro /dev/sda $FLOPPY_PATH
            sleep 5
        fi
        echo "$(date) - Searching for music files" | tee -a $LOGFILE
        if ls $FLOPPY_PATH/*.vgz &> /dev/null; then
            echo "$(date) - VGZ files found" | tee -a $LOGFILE
            if ! screen -list | grep -q "vgmplay"; then
                echo "$(date) - Starting vgmplay" | tee -a $LOGFILE
                screen -dmS vgmplay /usr/local/bin/vgmplay-pvgmp4f.py
            fi
        elif ls $FLOPPY_PATH/*.spc &> /dev/null || ls $FLOPPY_PATH/*.m3u &> /dev/null; then
            echo "$(date) - SPC files or M3U playlist found" | tee -a $LOGFILE
            if ! ps aux | grep -q "[m]ocp"; then
                echo "$(date) - Starting moc server" | tee -a $LOGFILE
                /usr/local/bin/mocp-pvgmp4f.py &>>$LOGFILE
                sleep 5
                if ! ps aux | grep -q "[m]ocp"; then
                    echo "$(date) - Failed to start moc" | tee -a $LOGFILE
                else
                    echo "$(date) - MOC state: $(/usr/bin/mocp -i | tee -a $LOGFILE)"
                fi
            else
                echo "$(date) - MOC is already running" | tee -a $LOGFILE
            fi
        else
            echo "$(date) - Music files not found" | tee -a $LOGFILE
        fi
    else
        echo "$(date) - Floppy disk not detected, stopping music" | tee -a $LOGFILE
        screen -S vgmplay -X quit
        /usr/bin/mocp -x &>>$LOGFILE
        sudo umount /mnt/floppy
    fi
    echo "$(date) - Sleeping for 5 seconds" | tee -a $LOGFILE
    sleep 5
done
EOF

# Make the main script executable and change the ownership
echo "Making the main script executable and changing ownership..."
sudo chmod +x /usr/local/bin/pvgmp4f.sh
sudo chown music:music /usr/local/bin/pvgmp4f.sh

# Create the service
echo "Creating the service..."
cat << EOF | sudo tee /etc/systemd/system/music_player.service
[Unit]
Description=Music Player for Floppy Disks
After=multi-user.target

[Service]
User=music
Group=music
ExecStart=/usr/local/bin/pvgmp4f.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Create the udev rule to ensure the floppy drive is mounted
echo "Creating udev rule..."
cat << EOF | sudo tee /etc/udev/rules.d/99-music-player.rules
KERNEL=="sda", ACTION=="change", RUN+="/bin/systemctl start music_player.service"
EOF

# Add 'music' user to sudoers file
echo "Updating sudoers file..."
echo "music ALL=NOPASSWD: /usr/bin/mount" >> /etc/sudoers
echo "music ALL=NOPASSWD: /usr/bin/umount" >> /etc/sudoers

# Create directory for floppy
echo "Creating directory for floppy..."
mkdir /mnt/floppy
sudo chown music:music /mnt/floppy

# Create log file
echo "Creating log file and directory..."
sudo mkdir /var/log/music_player
sudo chown music:music /var/log/music_player
sudo touch /var/log/music_player/music_player.log && sudo chown music:music /var/log/music_player/music_player.log

# Reload the udev rules
echo "Reloading udev rules..."
sudo udevadm control --reload-rules
sleep 5

# Enable and start the service
echo "Enabling and starting the service..."
sudo systemctl daemon-reload
sudo systemctl enable music_player.service
sudo systemctl start music_player.service

echo "Installation completed successfully!"
exit 0
