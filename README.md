#PVGMP4F
---
Pi Video Game Music Player 4 Floppy

PVGMP4F is a bash and python based application that enables playing video game music on a Linux machine from a floppy disk.
Getting Started

This README will guide you through the installation and usage of the PVGMP4F application.

### Prerequisites

To run PVGMP4F, you will need a Linux machine with:

    A floppy disk drive.
    A floppy disk with video game music files in the following formats: .vgz, .spc, and an accompanying .m3u playlist.

### Installation

To install PVGMP4F, follow these steps:

    Clone this repository to your machine or download the scripts directly.

    Open a terminal.

    Navigate to the directory where the script files are located.

    Run the following command to execute the installation script:

    sudo bash build_script.sh

The script will install necessary dependencies, create a user named 'music' to run the player, download and install VGMPlay, create player scripts, and setup a systemd service for automatic operation.

Note: The installation script must be run with root privileges for it to function correctly.
Usage

After successful installation, the PVGMP4F application will automatically start playing music files on the inserted floppy disk.

When a floppy disk is inserted, the service will mount the floppy drive and search for .vgz, .spc, or .m3u files. Depending on the found file format, it will start the corresponding player.

The players run inside screen sessions, allowing them to persist across logouts and reboots.

Logs related to the application are stored in /var/log/music_player/music_player.log.

### Tools
##### m3u-absolute-path.py
prefixes the entries in the m3u file on the floppy mounted to /mnt/floppy. Required for some reason.
```
m3u-absolute-path.py /mnt/floppy/playlist.m3u
```

### Troubleshooting

If you encounter any issues with the PVGMP4F application, you can refer to the log file located at /var/log/music_player/music_player.log.
Contributing

Please refer to each file's source code for more details. We welcome pull requests, bug fixes and issue reports. Before proposing a change, please discuss your change by raising an issue.
License

This project is released under the MIT License. See LICENSE for more details.
