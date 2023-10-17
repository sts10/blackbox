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

lsof -t -i :5000 | xargs kill -9
lsof -t -i :5001 | xargs kill -9

# Update and upgrade
apt update && apt -y dist-upgrade && apt -y autoremove

# Install required packages
apt-get -y install git python3 python3-venv python3-pip nginx tor whiptail libnginx-mod-http-geoip geoip-database unattended-upgrades gunicorn libssl-dev net-tools jq fail2ban ufw

# Install mkcert and its dependencies
echo "Installing mkcert and its dependencies..."
apt install -y libnss3-tools
wget https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-arm64
sleep 10
chmod +x mkcert-v1.4.4-linux-arm64
mv mkcert-v1.4.4-linux-arm64 /usr/local/bin/mkcert
export CAROOT="/home/hush/.local/share/mkcert"
mkdir -p "$CAROOT"  # Ensure the directory exists
mkcert -install

# Create a certificate for blackbox.local
echo "Creating certificate for blackbox.local..."
mkcert blackbox.local

# Move and link the certificates to Nginx's directory (optional, modify as needed)
mv blackbox.local.pem /etc/nginx/
mv blackbox.local-key.pem /etc/nginx/
echo "Certificate and key for blackbox.local have been created and moved to /etc/nginx/."

# Restore Git repos
cd /home/hush/blackbox
git restore --source=HEAD --staged --worktree -- .
sleep 2
git reset HEAD -- .
sleep 2
git clean -fd .
sleep 2
git config pull.rebase false
sleep 2
git pull
sleep 2
chmod +x /home/hush/blackbox/scripts/install.sh # Make executable when the device reboots 

# Create a virtual environment and install dependencies
cd /home/hush/hushline
git restore --source=HEAD --staged --worktree -- .
sleep 2
git reset HEAD -- .
sleep 2
git clean -fd .
sleep 2
git config pull.rebase false
sleep 2
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

# Create a new script to capture information
cp /home/hush/blackbox/python/blackbox-setup.py /home/hush/hushline

# Configure Nginx
cp /home/hush/blackbox/nginx/hushline-setup.nginx /etc/nginx/sites-available

ln -sf /etc/nginx/sites-available/hushline-setup.nginx /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

if [ -e "/etc/nginx/sites-enabled/default" ]; then
    rm /etc/nginx/sites-enabled/default
fi
ln -sf /etc/nginx/sites-available/hushline-setup.nginx /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx || error_exit

# Move script to display status on the e-ink display
cp /home/hush/blackbox/python/qr-setup.py /home/hush/hushline
cp /home/hush/blackbox/templates/setup.html /home/hush/hushline/templates

# Move new styles
mv /home/hush/hushline/static/style.css /home/hush/hushline/static/style.css.old
cp /home/hush/blackbox/static/style.css /home/hush/hushline/static

nohup ./venv/bin/python3 qr-setup.py --host=0.0.0.0 &

# Launch Flask app for setup
nohup ./venv/bin/python3 blackbox-setup.py --host=0.0.0.0 &

sleep 5

cat /tmp/qr_code.txt

echo "The Flask app for setup is running. Please complete the setup by navigating to https://blackbox.local/setup."

# Wait for user to complete setup form
while [ ! -f "/tmp/setup_config.json" ]; do
    sleep 5
done

# Read the configuration
EMAIL=$(jq -r '.email' /tmp/setup_config.json)
NOTIFY_SMTP_SERVER=$(jq -r '.smtp_server' /tmp/setup_config.json)
NOTIFY_PASSWORD=$(jq -r '.password' /tmp/setup_config.json)
NOTIFY_SMTP_PORT=$(jq -r '.smtp_port' /tmp/setup_config.json)

# Kill the Flask setup process and delete the install script
pkill -f blackbox-setup.py
rm /home/hush/hushline/blackbox-setup.py
rm /etc/nginx/sites-available/hushline-setup.nginx
rm /etc/nginx/sites-enabled/hushline-setup.nginx

# Create a systemd service
cat >/etc/systemd/system/blackbox.service <<EOL
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

# Make service file read-only and remove temp file
chmod 444 /etc/systemd/system/blackbox.service
rm /tmp/setup_config.json

systemctl daemon-reload
systemctl enable blackbox.service
systemctl start blackbox.service

# Check if the application is running and listening on the expected address and port
sleep 5
if ! netstat -tuln | grep -q '127.0.0.1:5000'; then
    echo "The application is not running as expected. Please check the application logs for more details."
    error_exit
fi

# Create Tor configuration file
mv /home/hush/blackbox/config/torrc /etc/tor

# Restart Tor service
systemctl restart tor.service
sleep 10

# Get the Onion address
ONION_ADDRESS=$(cat /var/lib/tor/hidden_service/hostname)

# Configure Nginx
cp /home/hush/blackbox/nginx/hush-line.nginx /etc/nginx/sites-available
cp /home/hush/blackbox/nginx/nginx.conf /etc/nginx

ln -sf /etc/nginx/sites-available/hush-line.nginx /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

if [ -e "/etc/nginx/sites-enabled/default" ]; then
    rm /etc/nginx/sites-enabled/default
fi
ln -sf /etc/nginx/sites-available/hush-line.nginx /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx || error_exit

# System status indicator
display_status_indicator() {
    local status="$(systemctl is-active blackbox.service)"
    if [ "$status" = "active" ]; then
        printf "\n\033[32m●\033[0m Hush Line is running\n$ONION_ADDRESS\n\n"
    else
        printf "\n\033[31m●\033[0m Hush Line is not running\n\n"
    fi
}

# Move Blackbox HTML
mv /home/hush/hushline/templates/index.html /home/hush/hushline/templates/index.html.old
cp /home/hush/blackbox/templates/index.html /home/hush/hushline/templates

# Create Info Page
cat >/home/hush/hushline/templates/info.html <<EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="author" content="Science & Design, Inc.">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="A reasonably private and secure personal tip line.">
    <meta name="theme-color" content="#7D25C1">

    <title>Blackbox Info</title>

    <link rel="apple-touch-icon" sizes="180x180" href="{{ url_for('static', filename='favicon/apple-touch-icon.png') }}">
    <link rel="icon" type="image/png" href="{{ url_for('static', filename='favicon/favicon-32x32.png') }}" sizes="32x32">
    <link rel="icon" type="image/png" href="{{ url_for('static', filename='favicon/favicon-16x16.png') }}" sizes="16x16">
    <link rel="icon" type="image/png" href="{{ url_for('static', filename='favicon/android-chrome-192x192.png') }}" sizes="192x192">
    <link rel="icon" type="image/png" href="{{ url_for('static', filename='favicon/android-chrome-512x512.png') }}" sizes="512x512">
    <link rel="icon" type="image/x-icon" href="{{ url_for('static', filename='favicon/favicon.ico') }}">
    <link rel="stylesheet" href="{{ url_for('static', filename='style.css') }}">
</head>
<body class="info">
    <header>
        <div class="wrapper">
            <h1>B14CKB0X</h1>
            <a href="https://en.wikipedia.org/wiki/Special:Random" class="btn" rel="noopener noreferrer">Close App</a>
        </div>
    </header>
    <section>
        <div class="wrapper">
            <h2>👋<br>Welcome to Blackbox</h2>
            <p>Blackbox is an anonymous tip line. You should use it when you have information you think shows evidence of wrongdoing, including:</p>
            <ul>
                <li>a violation of law, rule, or regulation,</li>
                <li>gross mismanagement,</li>
                <li>a gross waste of funds,</li>
                <li>abuse of authority, or</li>
                <li>a substantial danger to public health or safety.</li>
            </ul>
            <p>To send a Blackbox message, first, <a href="https://www.torproject.org/download/" target="_blank">download Tor Browser</a>, then use it to visit: <pre>$ONION_ADDRESS</pre></p>
        </div>
    </section>
    <script src="{{ url_for('static', filename='jquery-min.js') }}"></script>
    <script src="{{ url_for('static', filename='main.js') }}"></script>
</body>
</html>
EOL

# Configure Unattended Upgrades
cp /home/hush/blackbox/config/50unattended-upgrades /etc/apt/apt.conf.d
cp /home/hush/blackbox/config/20auto-upgrades /etc/apt/apt.conf.d

systemctl restart unattended-upgrades

echo "Automatic updates have been installed and configured."

# Configure Fail2Ban

echo "Configuring fail2ban..."

systemctl start fail2ban
systemctl enable fail2ban
cp /etc/fail2ban/jail.{conf,local}

cp /home/hush/blackbox/config/jail.local /etc/fail2ban

systemctl restart fail2ban

HUSHLINE_PATH="/home/hush/hushline"

send_email() {
    python3 << END
import smtplib
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import pgpy
import warnings
from cryptography.utils import CryptographyDeprecationWarning

warnings.filterwarnings("ignore", category=CryptographyDeprecationWarning)

def send_notification_email(smtp_server, smtp_port, email, password):
    subject = "🎉 Blackbox Installation Complete"
    message = "Blackbox has been successfully installed! In a moment, your device will reboot.\n\nYou can visit your tip line when you see \"Blackbox is running\" on your e-Paper display. If you can't immediately connect, don't panic; this is normal, as your device's information sometimes takes a few minutes to publish.\n\nYour Hush Line address is:\nhttp://$ONION_ADDRESS\n\nTo send a message, enter your address into Tor Browser. To find information about your Hush Line, including tips for when to use it, visit: http://$ONION_ADDRESS/info. If you still need to download Tor Browser, get it from https://torproject.org/download.\n\nHush Line is a free and open-source tool by Science & Design, Inc. Learn more about us at https://scidsg.org.\n\nIf you've found this resource useful, please consider making a donation at https://opencollective.com/scidsg."

    # Load the public key from its path
    key_path = os.path.expanduser('$HUSHLINE_PATH/public_key.asc')  # Use os to expand the path
    with open(key_path, 'r') as key_file:
        key_data = key_file.read()
        PUBLIC_KEY, _ = pgpy.PGPKey.from_blob(key_data)

    # Encrypt the message
    encrypted_message = str(PUBLIC_KEY.encrypt(pgpy.PGPMessage.new(message)))

    # Construct the email
    msg = MIMEMultipart()
    msg['From'] = email
    msg['To'] = email
    msg['Subject'] = subject
    msg.attach(MIMEText(encrypted_message, 'plain'))

    try:
        server = smtplib.SMTP_SSL(smtp_server, smtp_port)
        server.login(email, password)
        server.sendmail(email, [email], msg.as_string())
        server.quit()
    except Exception as e:
        print(f"Failed to send email: {e}")

send_notification_email("$NOTIFY_SMTP_SERVER", $NOTIFY_SMTP_PORT, "$EMAIL", "$NOTIFY_PASSWORD")
END
}

echo "
✅ Installation complete!
                                               
Hush Line is a product by Science & Design. 
Learn more about us at https://scidsg.org.
Have feedback? Send us an email at hushline@scidsg.org."

# Display system status on login
echo "display_status_indicator() {
    local status=\"\$(systemctl is-active blackbox.service)\"
    if [ \"\$status\" = \"active\" ]; then
        printf \"\n\033[32m●\033[0m Hush Line is running\nhttp://$ONION_ADDRESS\n\n\"
    else
        printf \"\n\033[31m●\033[0m Hush Line is not running\n\n\"
    fi
}" >>/etc/bash.bashrc

echo "display_status_indicator" >>/etc/bash.bashrc
source /etc/bash.bashrc

systemctl restart blackbox

send_email

deactivate

# Disable the trap before exiting
trap - ERR

curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/scidsg/blackbox/main/scripts/display.sh | bash
