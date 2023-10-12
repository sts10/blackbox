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

cd $HOME
git clone https://github.com/scidsg/hushline.git
git clone https://github.com/scidsg/blackbox.git
chmod +x $HOME/blackbox/v2/install.sh

# Create a new script to display status on the e-ink display
cat >/etc/systemd/system/blackbox-installer.service <<EOL
[Unit]
Description=Blackbox Installation Helper
After=multi-user.target

[Service]
ExecStart=$HOME/blackbox/v2/install.sh
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL

systemctl enable blackbox-installer.service

apt-get -y install git python3 python3-venv python3-pip nginx tor libnginx-mod-http-geoip geoip-database unattended-upgrades gunicorn libssl-dev net-tools jq python3-flask python3-setuptools python3-requests python3-cryptography python3-gnupg

# Create a virtual environment for installing remaining Python packages
python3 -m venv /home/hush/venv

# Activate the virtual environment
source /home/hush/venv/bin/activate

# Install Waveshare e-Paper library and other Python packages
pip install setuptools-rust pgpy gunicorn segno qrcode[pil] RPi.GPIO spidev

# Deactivate the virtual environment
deactivate