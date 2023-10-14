#!/bin/bash

#Run as root
if [[ $EUID -ne 0 ]]; then
  echo "Script needs to run as root. Elevating permissions now."
  exec sudo /bin/bash "$0" "$@"
fi

# Weclome

echo "
██████  ██       █████   ██████ ██   ██ ██████   ██████  ██   ██ 
██   ██ ██      ██   ██ ██      ██  ██  ██   ██ ██    ██  ██ ██  
██████  ██      ███████ ██      █████   ██████  ██    ██   ███   
██   ██ ██      ██   ██ ██      ██  ██  ██   ██ ██    ██  ██ ██  
██████  ███████ ██   ██  ██████ ██   ██ ██████   ██████  ██   ██ 

The physical product for Hush Line.
https://hushline
"
sleep 3

# Enable SPI interface
raspi-config nonint do_spi 0

# Update system
apt update && apt -y dist-upgrade && apt -y autoremove

git clone https://github.com/scidsg/hushline.git
git clone https://github.com/scidsg/blackbox.git
chmod +x /home/hush/blackbox/scripts/install.sh

# Create a new script to display status on the e-ink display
cat >/etc/systemd/system/blackbox-installer.service <<EOL
[Unit]
Description=Blackbox Installation Helper
After=multi-user.target

[Service]
ExecStart=/home/hush/blackbox/scripts/install.sh
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl enable blackbox-installer.service

sudo apt-get -y install git python3 python3-venv python3-pip nginx tor libnginx-mod-http-geoip geoip-database unattended-upgrades gunicorn libssl-dev net-tools jq

# Install Waveshare e-Paper library
pip3 install flask setuptools-rust pgpy gunicorn cryptography segno requests
pip3 install qrcode[pil]
pip3 install requests python-gnupg

# Install other Python packages
pip3 install RPi.GPIO spidev

# Configure UFW (Uncomplicated Firewall)

echo "Configuring UFW..."
sleep 1
echo "Disabling SSH access..."

# Default rules
ufw default deny incoming
ufw default allow outgoing
ufw allow 80/tcp
ufw allow 443/tcp
ufw deny proto tcp from any to any port 22

# Logging
ufw logging on

# Enable UFW non-interactively
echo "y" | ufw enable

echo "UFW configuration complete."

# Disable USB
echo "Disabling USB access..."
echo "dtoverlay=disable-usb" | tee -a /boot/config.txt
sleep 3