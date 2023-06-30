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
sudo apt-get install -y python3 moc screen unzip libao-dev libdbus-1-dev moc-ffmpeg-plugin
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

player_process = None

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
    global player_process
    player_process = None
    processes = ['vgmplay', 'screen', 'mocp']
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

def is_process_running(process):
    if process is None:
        return False
    # If the process is still running, returncode should be None
    return process.returncode is None

def is_floppy_mounted():
    # os.path.ismount will return True if the path is a mount point
    return os.path.ismount(FLOPPY_MOUNT)

def is_floppy_present():
    # os.path.exists will return True if the path exists
    return os.path.exists(FLOPPY_DEV)

def handle_vgz(folder_path):
    global player_process
    content = get_folder_content(folder_path)
    vgz_files = [f for f in content if f.lower().endswith('.vgz')]
    logging.debug('Checking for .vgz files.')
    if vgz_files:
        m3u_files = [f for f in content if f.lower().endswith('.m3u')]
        if m3u_files:
            try:
                logging.debug(f'Starting vgmplay with m3u files: {m3u_files}')
                command = ['screen', '-dmS', SCREEN_SESSION_NAME, VGZ_PLAYER] + m3u_files
                player_process = subprocess.Popen(command)
            except Exception as e:
                logging.exception(f'Failed to start vgmplay: {e}')
        else:
            logging.debug('No .m3u files found.')

def handle_spc(folder_path):
    global player_process
    content = get_folder_content(folder_path)
    spc_files = [f for f in content if f.lower().endswith('.spc')]
    logging.debug('Checking for .spc files.')
    if spc_files:
        m3u_files = [f for f in content if f.lower().endswith('.m3u')]
        if m3u_files:
            try:
                logging.debug(f'Starting mocp with m3u files: {m3u_files}')
                command = ['mocp', '-S', '-O', 'AutoNext=yes', '-O', 'Precache=no']  # Start the MOC server
                subprocess.Popen(command)
                time.sleep(1)  # Give MOC server time to start
                command = ['mocp', '-a'] + m3u_files  # Add the music files to the playlist
                subprocess.Popen(command)
                time.sleep(1)  # Give MOC some time to add files to the playlist
                command = ['mocp', '-p']  # Start playing
                player_process = subprocess.Popen(command)
            except Exception as e:
                logging.exception(f'Failed to start mocp: {e}')
        else:
            logging.debug('No .m3u files found.')

def main(debug=False):
    global player_process
    while True:
        if is_floppy_present() and not is_floppy_mounted():
            mount_floppy()

        if is_floppy_mounted():
            if not is_process_running(player_process):
                kill_running_players()  # Kill running players before starting
                handle_vgz(FLOPPY_MOUNT)
                handle_spc(FLOPPY_MOUNT)
                # Check if a player process is running after attempting to handle the files
                if is_process_running(player_process):
                    while True:
                        if not is_floppy_present() or not is_floppy_mounted():
                            kill_running_players()
                            if is_floppy_mounted():
                                unmount_floppy()
                            break
                        if not is_process_running(player_process):
                            break
                        time.sleep(5)

        time.sleep(5)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Music player for floppy disks.')
    parser.add_argument('-d', '--debug', help='Enable debug logging.', action='store_true')
    args = parser.parse_args()

    logging.basicConfig(level=logging.DEBUG if args.debug else logging.WARNING,
                        format='%(asctime)s %(levelname)-8s %(message)s',
                        datefmt='%Y-%m-%d %H:%M:%S',
                        handlers=[logging.StreamHandler(), logging.handlers.RotatingFileHandler('/var/log/pvgmp4f/PVGMP4F.log', maxBytes=10000, backupCount=3)])

    main(debug=args.debug)
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
sudo touch /var/log/pvgmp4f/PVGMP4F.log && sudo chown music:music /var/log/pvgmp4f/PVGMP4F.log

#create MOC config
sudo mkdir ~/home/.moc
cat << EOF | sudo tee /home/music/.moc/config
Precache = no
AutoNext = yes
EOF
chown music:music /home/music/.moc/config

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