#!/bin/bash

# Check if the script is running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please try again with 'sudo'."
   exit 1
fi

# Download and install gbsplay if not already installed
echo "Downoading and installing gbsplay"
echo "If there is stuttering during gbsplay, run the gbsplay-stutter-fix.sh script"
cd ~
mkdir tmp-gbsplay
cd tmp-gbsplay
if [ ! -d "gbsplay-0.0.94" ]; then
    wget https://github.com/mmitch/gbsplay/archive/refs/tags/0.0.94.zip
    unzip '0.0.94.zip'
    cd gbsplay-0.0.94
    ./configure
    make
    sudo make install
    sudo rm /usr/local/bin/gbsplay
    cp ./gbsplay /usr/local/bin/
    cd ~
fi
sleep 5