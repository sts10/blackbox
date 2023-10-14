#!/bin/bash

#Run as root
if [[ $EUID -ne 0 ]]; then
  echo "Script needs to run as root. Elevating permissions now."
  exec sudo /bin/bash "$0" "$@"
fi

# Enable SPI interface
# 0 for enable; 1 to disable
# See: https://www.raspberrypi.com/documentation/computers/configuration.html#spi-nonint
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

sudo apt-get -y install git python3 python3-venv python3-pip nginx tor libnginx-mod-http-geoip geoip-database unattended-upgrades gunicorn libssl-dev net-tools jq ufw

# Install Waveshare e-Paper library
pip3 install flask setuptools-rust pgpy gunicorn cryptography segno requests
pip3 install qrcode[pil]
pip3 install requests python-gnupg

# Install other Python packages
pip3 install RPi.GPIO spidev

# Create a new script to display status on the e-ink display
mv /home/hush/blackbox/python/display_status.py /home/hush/hushline
mv /home/hush/blackbox/python/clear_display.py /home/hush/hushline

# Clear display before shutdown
mv /home/hush/blackbox/service/clear-display.service /etc/systemd/system
mv /home/hush/blackbox/service/display-status.service /etc/systemd/system
systemctl daemon-reload
systemctl enable clear-display.service
systemctl enable display-status.service
systemctl start display-status.service

# Disable SSH and USB
echo "Disabling SSH access..."
ufw deny proto tcp from any to any port 22
echo "y" | ufw enable
sleep 3
echo "Disabling USB access..."
echo "dtoverlay=disable-usb" | tee -a /boot/config.txt
sleep 3

# Shutdown the device
shutdown -h now