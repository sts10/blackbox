#!/bin/bash

#Run as root
if [[ $EUID -ne 0 ]]; then
  echo "Script needs to run as root. Elevating permissions now."
  exec sudo /bin/bash "$0" "$@"
fi

# Function to display error message and exit
error_exit() {
    echo "An error occurred during installation. Please check the output above for more details."
    exit 1
}

# Trap any errors and call error_exit function
trap error_exit ERR

# Update and upgrade
sudo apt update && sudo apt -y dist-upgrade && sudo apt -y autoremove

# Install required packages
sudo apt-get -y install git python3 python3-venv python3-pip nginx tor whiptail libnginx-mod-http-geoip geoip-database unattended-upgrades gunicorn libssl-dev net-tools jq fail2ban ufw

# Create a virtual environment and install dependencies
cd /home/hush/hushline
git restore --source=HEAD --staged --worktree -- .
git reset HEAD -- .
git clean -fd .
git config pull.rebase false
git pull

python3 -m venv venv
source venv/bin/activate
pip3 install flask setuptools-rust pgpy gunicorn cryptography segno requests
pip3 install -r requirements.txt

# Install Waveshare e-Paper library
if [ ! -d "e-Paper" ]; then
    git clone https://github.com/waveshare/e-Paper.git
else
    echo "Directory e-Paper already exists. Skipping clone."
fi
pip3 install ./e-Paper/RaspberryPi_JetsonNano/python/
pip3 install qrcode[pil]
pip3 install requests python-gnupg

# Install other Python packages
pip3 install RPi.GPIO spidev
apt-get -y autoremove

# Enable SPI interface
if ! grep -q "dtparam=spi=on" /boot/config.txt; then
    echo "dtparam=spi=on" | sudo tee -a /boot/config.txt
    echo "SPI interface enabled."
else
    echo "SPI interface is already enabled."
fi

# Create a new script to capture information
cat >/home/hush/hushline/blackbox-setup.py <<EOL
from flask import Flask, request, render_template, redirect, url_for
import json
import os
import segno
import requests
import socket

app = Flask(__name__)

# Flag to indicate whether setup is complete
setup_complete = os.path.exists('/tmp/setup_config.json')

@app.route('/setup', methods=['GET', 'POST'])
def setup():
    global setup_complete
    if setup_complete:
        return redirect(url_for('index'))
    
    if request.method == 'POST':
        email = request.form.get('email')
        smtp_server = request.form.get('smtp_server')
        password = request.form.get('password')
        smtp_port = request.form.get('smtp_port')
        pgp_public_key = request.form.get('pgp_public_key')

        # Save the configuration
        with open('/tmp/setup_config.json', 'w') as f:
            json.dump({
                'email': email,
                'smtp_server': smtp_server,
                'password': password,
                'smtp_port': smtp_port,
                'pgp_public_key': pgp_public_key
            }, f)

        setup_complete = True

        # Save the provided PGP key to a file
        with open('/home/hush/hushline/public_key.asc', 'w') as keyfile:
            keyfile.write(pgp_public_key)

        return redirect(url_for('index'))

    return render_template('setup.html')

@app.route('/')
def index():
    if not setup_complete:
        return redirect(url_for('setup'))
    
    return '👍 Successfully submitted! The installation script will now resume.'

if __name__ == '__main__':
    qr = segno.make(f'http://hushline.local:5000/setup')
    with open("/tmp/qr_code.txt", "w") as f:
        qr.terminal(out=f)
    app.run(host='hushline.local', port=5000)
EOL

# Create a new script to display status on the e-ink display
cat >/home/hush/hushline/qr-setup.py <<EOL
import os
import sys
import time
import qrcode
from waveshare_epd import epd2in7
from PIL import Image, ImageDraw, ImageFont

def generate_qr_code(data):
    print("Generating QR code...")
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    qr.add_data(data)
    qr.make(fit=True)
    img = qr.make_image(fill='black', back_color='white')
    img = img.convert('1')  # Convert to 1-bit image
    
    # Calculate the new size preserving aspect ratio
    base_width, base_height = img.size
    aspect_ratio = float(base_width) / float(base_height)
    new_height = int(epd2in7.EPD_HEIGHT)
    new_width = int(aspect_ratio * new_height)

    if new_width > epd2in7.EPD_WIDTH:
        new_width = epd2in7.EPD_WIDTH
        new_height = int(new_width / aspect_ratio)

    # Calculate position to paste
    x_pos = (epd2in7.EPD_WIDTH - new_width) // 2
    y_pos = (epd2in7.EPD_HEIGHT - new_height) // 2
    
    img_resized = img.resize((new_width, new_height))
    
    # Create a blank (white) image to paste the QR code on
    img_blank = Image.new('1', (epd2in7.EPD_WIDTH, epd2in7.EPD_HEIGHT), 255)
    img_blank.paste(img_resized, (x_pos, y_pos))

    # Save to disk for debugging
    img_blank.save("debug_qr_code.png")
    
    return img_blank

def main():
    epd = epd2in7.EPD()
    epd.init()

    # Generate QR code for your URL or data
    qr_code_image = generate_qr_code("http://hushline.local:5000/setup")

    # Clear frame memory
    epd.Clear(0xFF)
    
    # Display the QR code
    epd.display(epd.getbuffer(qr_code_image))

    time.sleep(2)

    # You could also put it to sleep or perform other operations on the display here
    epd.sleep()
    
if __name__ == "__main__":
    main()
EOL

nohup ./venv/bin/python3 qr-setup.py --host=0.0.0.0 &

# Launch Flask app for setup
nohup python3 blackbox-setup.py --host=0.0.0.0 &

sleep 5

# Display the QR code from the file
cat /tmp/qr_code.txt

echo "The Flask app for setup is running. Please complete the setup by navigating to http://hushline.local:5000/setup."

# Wait for user to complete setup form
while [ ! -f "/tmp/setup_config.json" ]; do
    sleep 5
done

# Read the configuration
EMAIL=$(jq -r '.email' /tmp/setup_config.json)
NOTIFY_SMTP_SERVER=$(jq -r '.smtp_server' /tmp/setup_config.json)
NOTIFY_PASSWORD=$(jq -r '.password' /tmp/setup_config.json)
NOTIFY_SMTP_PORT=$(jq -r '.smtp_port' /tmp/setup_config.json)

# Kill the Flask setup process
pkill -f blackbox-setup.py

# Create a systemd service
cat >/etc/systemd/system/hush-line.service <<EOL
[Unit]
Description=Hush Line Web App
After=network.target
[Service]
User=root
WorkingDirectory=$PWD
Environment="DOMAIN=localhost"
Environment="EMAIL=$EMAIL"
Environment="NOTIFY_PASSWORD=$NOTIFY_PASSWORD"
Environment="NOTIFY_SMTP_SERVER=$NOTIFY_SMTP_SERVER"
Environment="NOTIFY_SMTP_PORT=$NOTIFY_SMTP_PORT"
ExecStart=$PWD/venv/bin/gunicorn --bind 127.0.0.1:5000 app:app
Restart=always
[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable hush-line.service
sudo systemctl start hush-line.service

# Check if the application is running and listening on the expected address and port
sleep 5
if ! netstat -tuln | grep -q '127.0.0.1:5000'; then
    echo "The application is not running as expected. Please check the application logs for more details."
    error_exit
fi

# Create Tor configuration file
sudo tee /etc/tor/torrc <<EOL
RunAsDaemon 1
HiddenServiceDir /var/lib/tor/hidden_service/
HiddenServicePort 80 127.0.0.1:5000
EOL

# Restart Tor service
sudo systemctl restart tor.service
sleep 10

# Get the Onion address
ONION_ADDRESS=$(sudo cat /var/lib/tor/hidden_service/hostname)

# Configure Nginx
cat >/etc/nginx/sites-available/hush-line.nginx <<EOL
server {
    listen 80;
    server_name localhost;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
    
        add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
        add_header X-Frame-Options DENY;
        add_header Onion-Location http://$ONION_ADDRESS\$request_uri;
        add_header X-Content-Type-Options nosniff;
        add_header Content-Security-Policy "default-src 'self'; frame-ancestors 'none'";
        add_header Permissions-Policy "geolocation=(), midi=(), notifications=(), push=(), sync-xhr=(), microphone=(), camera=(), magnetometer=(), gyroscope=(), speaker=(), vibrate=(), fullscreen=(), payment=(), interest-cohort=()";
        add_header Referrer-Policy "no-referrer";
        add_header X-XSS-Protection "1; mode=block";
}
EOL

# Configure Nginx with privacy-preserving logging
cat >/etc/nginx/nginx.conf <<EOL
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;
events {
        worker_connections 768;
        # multi_accept on;
}
http {
        ##
        # Basic Settings
        ##
        sendfile on;
        tcp_nopush on;
        types_hash_max_size 2048;
        # server_tokens off;
        # server_names_hash_bucket_size 64;