# pi-VGM-player
---
---

## Requirements
---
- raspberry pi with arm version of raspberry pi OS
- usb floppy
- floppy disk with vgz extension files accompanied with .m3u playlist file (root of floppy (no folders))
- small image for future use (display)

---
---

## Copying files to the floppy with SCP
- the home directory of the user should have a "music" folder
- from windows, copy the album folder to the home folder on the pi.
- shift + right-click and click Open in Terminal ![[Pasted image 20230619223232.png]]
```
scp -r .\game_music_folder\ [pi_username]@[IP_of_pi]:/home/music/music
```
![[Pasted image 20230619224115.png]]

- From the pi, move the files to the floppy 
```
sudo mv -r /home/music/music/[name_of_game_folder]/* /mnt/floppy
```
![[Pasted image 20230619230205.png]]



## Test song
```
vgmplay /mnt/floppy/[songname].vgz
```


---
---


# Literal Instructions
DL RaspberryOS 32 lite (bullseye) (deb 11)
- set it up

### Update && Upgrade
```
sudo apt update
sudo apt upgrade -y
```

### Install dependencies
```
sudo apt-get install udev pmount mpg123 make gcc zlib1g-dev libao-dev libdbus-1-dev screen
```

### Download VGMPlayer
```
wget 'https://github.com/vgmrips/vgmplay/archive/refs/heads/master.zip'
```

### Unzip VGMPlayer
```
unzip master.zip
```

#### cd Into the Directory
```
cd vgmplay-master/VGMPlay
```

#### compile the binaries with 'make'
```
make
```

#### install the binaries
```
sudo make install
```
```
sudo make play_install
```

### Create udev Rule
```
sudo nano /etc/udev/rules.d/90-autofloppy.rules
```
```
# 90-autofloppy.rules
KERNEL=="sda", ACTION=="add", RUN+="/bin/systemctl start floppy-player.service"
```

### make mountable folder
```
sudo mkdir /mnt/floppy
```

### Create floppyscript
```
sudo nano /usr/local/bin/floppyscript
```
```
#!/bin/bash

LOGFILE="/var/log/floppyscript.log"
FLOPPY_PATH="/mnt/floppy"

echo "$(date) - Script started" | tee -a $LOGFILE

while true; do
    # Check if the floppy disk is inserted
    if [ -b /dev/sda ]; then
        # If the floppy disk is there, check if it's already mounted
        if ! grep -qs "$FLOPPY_PATH" /proc/mounts; then
            # If it's not already mounted, mount it
            echo "$(date) - Mounting floppy" | tee -a $LOGFILE
            mount /dev/sda $FLOPPY_PATH
            sleep 5 # Wait for the file system to become ready
        fi
        # Check if the music file is there
        if ls $FLOPPY_PATH/*.m3u &> /dev/null; then
            # And start playing music files with vgmplay
            echo "$(date) - M3U file detected" | tee -a $LOGFILE
            if ! screen -list | grep -q "vgmplay"; then
                screen -dmS vgmplay bash -c 'vgmplay /mnt/floppy/*.m3u'
            fi
        else
            echo "$(date) - M3U file not found" | tee -a $LOGFILE
        fi
    else
        # If the floppy disk is not there, unmount it
        echo "$(date) - Floppy disk not detected, unmounting floppy" | tee -a $LOGFILE
        umount /mnt/floppy
    fi
    sleep 5
done
```

#### give it permissions
```
sudo chmod 655 /usr/local/bin/floppyscript
```

### Create the Service
```
sudo nano /etc/systemd/system/floppy-player.service
```
```
[Unit]
Description=Play music from floppy

[Service]
Type=simple
ExecStart=/usr/bin/screen -dmS music /bin/bash /usr/local/bin/floppyscript
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

```
sudo chown root:root /etc/systemd/system/floppy-player.service
```
```
sudo chmod 644 /etc/systemd/system/floppy-player.service
```

```
sudo systemctl enable floppy-player.service
```
```
sudo systemctl start floppy-player.service
```

### Edit sudoers File
- there is probably a better way to do this
- it's probably very insecure
```
sudo nano /etc/sudoers
```
add these below "@includedir /etc/sudoers.d"
```
music ALL=(ALL:ALL) NOPASSWD: /bin/mount
music ALL=(ALL:ALL) NOPASSWD: /bin/umount
music ALL=(ALL:ALL) NOPASSWD: /usr/bin/vgmplay
music ALL=(ALL:ALL) NOPASSWD: /usr/local/bin/floppyscript
```

### fstab Entry
```
sudo nano /etc/fstab
```
```
/dev/sda  /mnt/floppy  vfat  defaults,user,umask=0000  0  0
```

### Bring it All Together
```
sudo mount -a
```
```bash
sudo udevadm control --reload-rules
```
```
sudo udevadm trigger
```

### check status of service
```
sudo systemctl status floppy-player.service
```
- if its stopped start it. If it doesn't start troubleshoot why
```
sudo systemctl start floppy-player.service
```

Tail the log file and insert a floppy
```
tail -f /var/log/floppyscript.log -n 15
```

Troubleshoot as needed, hopefully it works!


---
---


## Tips & Tricks
---

#### manually mount the floppy
- the directory /mnt/floppy must already exist
```
sudo mount -t vfat /dev/sda /mnt/floppy
```

---

#### build libvgm/vgmtools

install cmake
```plaintext
sudo apt update
sudo apt install -y cmake
```
```plaintext
cmake --version
```

vgmtools/libvgm
##### Tools
```
wget https://github.com/vgmrips/vgmtools/archive/refs/heads/master.zip
```
- unzip master.zip
- cd into extracted directory
- run cmake
```
cmake .
```
- once thats done run make
```
make
```

##### libvgm
```
wget https://github.com/ValleyBell/libvgm/archive/refs/heads/master.zip
```
- unzip master.zip
- cd into extracted directory
- run cmake
```
cmake .
```
- once thats done run make
```
make
```

---
#### Service tools

restart service
```
sudo systemctl restart floppy-player.service
```

check status of service
```
sudo systemctl status floppy-player.service
```

---

#### View audio volume on pi
```
alsamixer
```

---

#### find floppy /dev/ location
```
lsblk
```

---

