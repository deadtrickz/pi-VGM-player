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
echo "Creating the Python scripts..."
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

def handle_m3u(folder_path):
    content = get_folder_content(folder_path)
    m3u_files = [f for f in content if f.lower().endswith('.m3u')]
    if m3u_files:
        try:
            command = ['screen', '-dmS', SCREEN_SESSION_NAME, '/usr/local/bin/vgmplay'] + m3u_files
            subprocess.run(command, check=True)
        except Exception as e:
            logging.exception(f'Failed to start VGMPlay: {e}')

def main(folder_path):
    logging.basicConfig(level=logging.DEBUG)
    handle_m3u(folder_path)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='VGMPlay player for M3U playlists.')
    parser.add_argument('folder_path', type=str, help='Path to the folder containing the music files.')
    args = parser.parse_args()
    main(args.folder_path)
EOF

cat << 'EOF' | sudo tee /usr/local/bin/mocp-pvgmp4f.py
#!/usr/bin/env python3

import argparse
import logging
import os
import subprocess
import time

SCREEN_SESSION_NAME = 'mocp_session'

def get_folder_content(folder_path):
    return [os.path.join(folder_path, f) for f in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, f))]

def handle_m3u(folder_path):
    content = get_folder_content(folder_path)
    m3u_files = [f for f in content if f.lower().endswith('.m3u')]
    if m3u_files:
        try:
            command = ['mocp', '-S', '-O', 'AutoNext=yes', '-O', 'Precache=no']
            subprocess.run(command, check=True)
            time.sleep(1)
            command = ['mocp', '-c'] + m3u_files
            subprocess.run(command, check=True)
            time.sleep(1)
            command = ['mocp', '-p']
            subprocess.run(command, check=True)
        except Exception as e:
            logging.exception(f'Failed to start MOC player: {e}')

def main(folder_path):
    logging.basicConfig(level=logging.DEBUG)
    handle_m3u(folder_path)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='MOC player for M3U playlists.')
    parser.add_argument('folder_path', type=str, help='Path to the folder containing the music files.')
    args = parser.parse_args()
    main(args.folder_path)
EOF

# Make the player scripts executable and change the ownership
echo "Making player scripts executable and changing ownership..."
sudo chmod +x /usr/local/bin/vgmplay-pvgmp4f.py
sudo chmod +x /usr/local/bin/mocp-pvgmp4f.py
sudo chown music:music /usr/local/bin/vgmplay-pvgmp4f.py
sudo chown music:music /usr/local/bin/mocp-pvgmp4f.py

# Add the main script
echo "Adding the main script..."
cat << 'EOF' | sudo tee /usr/local/bin/pvgmp4f.py
#!/usr/bin/env python3

import argparse
import logging
import os
import subprocess
import time

FLOPPY_DEV = '/dev/sda'
FLOPPY_MOUNT = '/mnt/floppy'
SCREEN_SESSION_NAME = 'music_player_session'

def get_folder_content(folder_path):
    return [os.path.join(folder_path, f) for f in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, f))]

def kill_process(process_name):
    command = ['pgrep', '-f', process_name]
    try:
        process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if process.returncode == 0:
            pids = process.stdout.strip().split('\n')
            for pid in pids:
                subprocess.run(['kill', pid])
            logging.debug(f'{process_name}: {", ".join(pids)} found and terminated.')
    except Exception as e:
        logging.exception(f'Error occurred when trying to kill process {process_name}: {e}')

def kill_running_players():
    processes = ['vgmplay', 'mocp']
    for process in processes:
        kill_process(process)

def mount_floppy():
    try:
        subprocess.run(["sudo", "mount", "-t", "vfat", "-o", "ro", FLOPPY_DEV, FLOPPY_MOUNT])
        time.sleep(5)  # give the system time to mount
    except Exception as e:
        logging.exception(f'Error occurred when trying to mount floppy: {e}')

def unmount_floppy():
    try:
        subprocess.run(["sudo", "umount", FLOPPY_MOUNT])
        time.sleep(5)  # give the system time to unmount
    except Exception as e:
        logging.exception(f'Error occurred when trying to unmount floppy: {e}')

def handle_m3u_with_player(folder_path, player_path):
    content = get_folder_content(folder_path)
    m3u_files = [f for f in content if f.lower().endswith('.m3u')]
    if m3u_files:
        try:
            command = ['screen', '-dmS', SCREEN_SESSION_NAME, player_path, folder_path]
            subprocess.run(command, check=True)
        except Exception as e:
            logging.exception(f'Failed to start player: {e}')

def handle_floppy():
    logging.debug('New floppy detected.')
    mount_floppy()
    content = get_folder_content(FLOPPY_MOUNT)
    if any(f.lower().endswith('.spc') for f in content):
        handle_m3u_with_player(FLOPPY_MOUNT, '/usr/local/bin/mocp-pvgmp4f.py')
    elif any(f.lower().endswith('.vgz') for f in content):
        handle_m3u_with_player(FLOPPY_MOUNT, '/usr/local/bin/vgmplay-pvgmp4f.py')
    unmount_floppy()

def main():
    logging.basicConfig(filename='/var/log/pvgmp4f/pvgmp4f.log', level=logging.DEBUG)
    kill_running_players()
    handle_floppy()

if __name__ == '__main__':
    main()
EOF

# Make the main script executable and change the ownership
echo "Making the main script executable and changing ownership..."
sudo chmod +x /usr/local/bin/pvgmp4f.py
sudo chown music:music /usr/local/bin/pvgmp4f.py

# Create the service
echo "Creating the service..."
cat << EOF | sudo tee /etc/systemd/system/pvgmp4f.service
[Unit]
Description=Music Player for Floppy Disks
After=multi-user.target

[Service]
User=music
Group=music
ExecStart=/usr/local/bin/pvgmp4f.py /mnt/floppy
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Create the udev rule to ensure the floppy drive is mounted
echo "Creating udev rule..."
cat << EOF | sudo tee /etc/udev/rules.d/99-music-player.rules
KERNEL=="sda", ACTION=="change", RUN+="/bin/systemctl start pvgmp4f.service"
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
sudo mkdir /var/log/pvgmp4f
sudo chown music:music /var/log/pvgmp4f
sudo touch /var/log/pvgmp4f/pvgmp4f.log && sudo chown music:music /var/log/pvgmp4f/pvgmp4f.log

# Reload the udev rules
echo "Reloading udev rules..."
sudo udevadm control --reload-rules
sleep 5

# Enable and start the service
echo "Enabling and starting the service..."
sudo systemctl daemon-reload
sudo systemctl enable pvgmp4f.service
sudo systemctl start pvgmp4f.service

echo "Installation completed successfully!"
exit 0
