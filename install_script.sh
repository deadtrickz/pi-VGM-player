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

# Install Python3, MOC and Screen
echo "Installing Python3, MOC, and Screen..."
sudo apt-get install -y python3 moc screen unzip
sleep 5

# Create user 'music' with password PVGMP4F and adding it to appropriate groups
echo "Creating 'music' user and adding it to 'audio' and 'floppy' groups..."
sudo useradd -m music
echo "music:PVGMP4F" | sudo chpasswd
sudo usermod -a -G audio,floppy music

# Download and install VGMPlay
echo "Downloading and installing VGMPlay..."
cd ~
wget 'https://github.com/vgmrips/vgmplay/archive/refs/heads/master.zip'
unzip master.zip
cd vgmplay-master/VGMPlay
make
sudo make install
sudo make play_install
cd ~
sleep 5

# Add the Python script
echo "Adding Python script..."
cat << EOF | sudo tee /usr/local/bin/PVGMP4F.py
#!/usr/bin/env python3

import argparse
import logging
import os
import subprocess
import time
import logging.handlers

FLOPPY_DEV = '/dev/sda'
FLOPPY_MOUNT = '/mnt/floppy'
VGZ_PLAYER = '/usr/local/bin/vgmplay'
SPC_PLAYER = '/usr/bin/mocp'
SCREEN_SESSION_NAME = 'vgmplay_session'

def get_folder_content(folder_path):
    return [os.path.join(folder_path, f) for f in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, f))]

def kill_process(process_name):
    command = ['pgrep', '-f', process_name]
    process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if process.returncode == 0:
        pids = process.stdout.strip().split('\n')
        for pid in pids:
            subprocess.run(['kill', pid])
        print(f'{process_name}: {", ".join(pids)} found and terminated.')

def kill_running_players():
    processes = ['vgmplay', 'screen', 'mocp']
    for process in processes:
        kill_process(process)

def mount_floppy():
    subprocess.run(["mount", "-t", "vfat", "-o", "ro", FLOPPY_DEV, FLOPPY_MOUNT])
    time.sleep(5)  # give the system time to mount

def unmount_floppy():
    subprocess.run(["umount", FLOPPY_MOUNT])
    time.sleep(5)  # give the system time to unmount

def handle_vgz(folder_path, debug):
    content = get_folder_content(folder_path)
    vgz_files = [f for f in content if f.lower().endswith('.vgz')]
    if vgz_files and debug:
        logging.debug('Found .vgz files.')

    if vgz_files:
        m3u_files = [f for f in content if f.lower().endswith('.m3u')]
        if m3u_files:
            try:
                if debug:
                    logging.debug(f'Starting vgmplay with m3u files: {m3u_files}')
                command = ['screen', '-dmS', SCREEN_SESSION_NAME, VGZ_PLAYER] + m3u_files
                subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            except Exception as e:
                if debug:
                    logging.error(f'Failed to start vgmplay: {str(e)}')
        elif debug:
            logging.debug('No .m3u files found.')

def handle_spc(folder_path, debug):
    content = get_folder_content(folder_path)
    spc_files = [f for f in content if f.lower().endswith('.spc')]
    if spc_files and debug:
        logging.debug('Found .spc files.')

    if spc_files:
        m3u_files = [f for f in content if f.lower().endswith('.m3u')]
        if m3u_files:
            try:
                if debug:
                    logging.debug(f'Starting mocp with m3u files: {m3u_files}')
                command = [SPC_PLAYER, '-S'] + m3u_files
                subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

                # Start playback after starting MOC server
                subprocess.run([SPC_PLAYER, '-p'])

            except Exception as e:
                if debug:
                    logging.error(f'Failed to start mocp: {str(e)}')
        elif debug:
            logging.debug('No .m3u files found.')

def main(debug):
    log_handler = logging.handlers.RotatingFileHandler('/var/log/PVGMP4F.log', maxBytes=5000, backupCount=5)
    log_format = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    log_handler.setFormatter(log_format)
    
    logger = logging.getLogger()
    logger.addHandler(log_handler)
    logger.setLevel(logging.DEBUG if debug else logging.INFO)
    
    while True:
        mount_floppy()
        if os.path.ismount(FLOPPY_MOUNT):
            kill_running_players()  # Kill running players before starting
            handle_vgz(FLOPPY_MOUNT, debug)
            handle_spc(FLOPPY_MOUNT, debug)
            unmount_floppy()
        time.sleep(5)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Play .vgz and .spc files.')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode.')
    args = parser.parse_args()
    main(args.debug)
EOF

# Make the script executable and change the ownership
echo "Making script executable and changing ownership..."
sudo chmod +x /usr/local/bin/PVGMP4F.py
sudo chown music:music /usr/local/bin/PVGMP4F.py

# Create the service
echo "Creating the service..."
cat << EOF | sudo tee /etc/systemd/system/pvgmp4f.service
[Unit]
Description=Pi Video Game Music Player 4 Floppies
After=multi-user.target

[Service]
User=music
Group=music
ExecStart=/usr/local/bin/PVGMP4F.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Create the udev rule to ensure the floppy drive is mounted
echo "Creating udev rule..."
cat << EOF | sudo tee /etc/udev/rules.d/99-pvgmp4f.rules
KERNEL=="sda", ACTION=="change", RUN+="/bin/systemctl start pvgmp4f.service"
EOF

# Add 'music' user to sudoers file
echo "Updating sudoers file..."
echo "music ALL=NOPASSWD: /bin/mount" >> /etc/sudoers
echo "music ALL=NOPASSWD: /bin/umount" >> /etc/sudoers

# Create directory for floppy
echo "Creating directory for floppy..."
mkdir /mnt/floppy
sudo chown music:music /mnt/floppy

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
