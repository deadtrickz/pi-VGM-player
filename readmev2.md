# Floppy Disk Music Player

This script automates the setup of a music player system for floppy disks. It allows you to play music files stored on floppy disks using different players, such as VGMPlay and MOC.

## Prerequisites

- Linux-based system
- Root access or sudo privileges

## Installation

1. Download the build_script.sh file.

2. Make the script executable:

   ```bash
   chmod +x build_script.sh
Run the script with root access or sudo:

bash
Copy code
sudo ./build_script.sh
Follow the on-screen instructions to complete the installation process.

Usage
Insert a floppy disk containing music files into the floppy drive.

The music player system will automatically detect the inserted floppy disk and start playing the music using the appropriate player (VGMPlay or MOC).

To change the floppy disk or stop the music playback, eject the current floppy disk.

Insert a new floppy disk to play music from a different collection.

Troubleshooting
If the music player system fails to start or play music, make sure the floppy disk is formatted correctly and contains supported music file formats (e.g., .vgz, .spc).

Check the system logs for any error messages related to the music player system:

bash
Copy code
sudo journalctl -u music_player.service
If the music player system does not detect the inserted floppy disk, make sure the floppy drive is functioning properly and the floppy disk is inserted correctly.

License
This project is licensed under the MIT License.