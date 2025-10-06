#!/bin/bash
set -e

CYAN='\033[0;36m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
RESET='\033[0m'
BOLD='\033[1m'

# ===============================
# BANNER
# ===============================
echo -e "${PURPLE}${BOLD}"
echo -e "${CYAN}
 
 ______              _         _                                             
|  ___ \            | |       | |                   _                        
| |   | |  ___    _ | |  ____ | | _   _   _  ____  | |_   ____   ____  _____ 
| |   | | / _ \  / || | / _  )| || \ | | | ||  _ \ |  _) / _  ) / ___)(___  )
| |   | || |_| |( (_| |( (/ / | | | || |_| || | | || |__( (/ / | |     / __/ 
|_|   |_| \___/  \____| \____)|_| |_| \____||_| |_| \___)\____)|_|    (_____)                   
                                
                                                                                                                                
${YELLOW}                      :: Powered by Noderhunterz ::
${NC}"
# ===== 1. Install Dependencies =====
echo "[+] Installing dependencies..."
sudo apt update
sudo apt install -y \
  xserver-xorg-video-dummy \
  lxde-core lxde-common lxsession \
  screen curl unzip wget ufw
echo "[+] Killing existing Sunshine, Cloudflared, LXDE, Xorg, and screen sessions..."
echo "[+] Checking and killing existing Sunshine, Cloudflared, LXDE, Xorg, and screen sessions..."
if pgrep sunshine > /dev/null; then
  echo "Killing sunshine processes..."
  pkill -9 sunshine
fi
if pgrep cloudflared > /dev/null; then
  echo "Killing cloudflared processes..."
  pkill -9 cloudflared
fi
if pgrep lxsession > /dev/null; then
  echo "Killing lxsession processes..."
  pkill -9 lxsession
fi
if pgrep lxpanel > /dev/null; then
  echo "Killing lxpanel processes..."
  pkill -9 lxpanel
fi
if pgrep openbox > /dev/null; then
  echo "Killing openbox processes..."
  pkill -9 openbox
fi
if pgrep Xorg > /dev/null; then
  echo "Killing Xorg processes..."
  pkill -f "Xorg :0"
  pkill -f "Xorg.*vt7"
fi
# Kill any screen sessions named sunshine
if screen -ls | grep -q sunshine; then
  echo "Killing sunshine screen sessions..."
  screen -ls | grep sunshine | awk '{print $1}' | xargs -r -n 1 screen -S {} -X
quit
fi
echo "[+] All related processes killed."
# ===== 2. Install Sunshine =====
if ! command -v sunshine &>/dev/null; then
    echo "[+] Installing Sunshine..."
    wget -O /tmp/sunshine.deb \
  https://github.com/LizardByte/Sunshine/releases/download/v0.23.1/sunshine-ubuntu-22.04-amd64.deb
sudo apt install -y /tmp/sunshine.deb
rm /tmp/sunshine.deb
else
    echo "[*] Sunshine already installed."
fi
echo "Configuring firewall for SSH & Sunshine..."
sudo ufw allow ssh
sudo ufw allow 47984/tcp
sudo ufw allow 47989/tcp
sudo ufw allow 48010/tcp
sudo ufw allow 47990/tcp
sudo ufw allow 47998:48002/udp
sudo ufw --force enable
# ===== 3. Install Cloudflared =====
if ! command -v cloudflared &>/dev/null; then
    echo "[+] Installing Cloudflared..."
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo apt install -y ./cloudflared-linux-amd64.deb
    rm cloudflared-linux-amd64.deb
else
    echo "[*] Cloudflared already installed."
fi
# ===== 4. Configure Dummy X Server =====
echo "[+] Configuring dummy Xorg display..."
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/10-evdev.conf > /dev/null <<EOF
Section "InputDevice"
    Identifier "Dummy Mouse"
    Driver "evdev"
    Option "Device" "/dev/uinput"
    Option "Emulate3Buttons" "true"
    Option "EmulateWheel" "true"
    Option "ZAxisMapping" "4 5"
EndSection
Section "InputDevice"
    Identifier "Dummy Keyboard"
    Driver "evdev"
    Option "Device" "/dev/uinput"
EndSection
EOF
sudo tee /etc/X11/xorg.conf.d/xorg.conf.dummy > /dev/null <<EOF
Section "Monitor"
    Identifier "Monitor0"
    HorizSync 28.0-80.0
    VertRefresh 48.0-75.0
    Option "DPMS"
EndSection
Section "Device"
    Identifier "Device0"
    Driver "dummy"
    VideoRam 256000
EndSection
Section "Screen"
    Identifier "Screen0"
    Device "Device0"
    Monitor "Monitor0"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1920x1080"
    EndSubSection
EndSection
EOF
sudo tee /etc/X11/xorg.conf.d/10-dummy.conf > /dev/null <<EOF
Section "Device"
    Identifier  "DummyDevice"
    Driver      "dummy"
    VideoRam    256000
EndSection
Section "Monitor"
    Identifier  "DummyMonitor"
    HorizSync   28.0-80.0
    VertRefresh 48.0-75.0
EndSection
Section "Screen"
    Identifier  "DummyScreen"
    Device      "DummyDevice"
    Monitor     "DummyMonitor"
    DefaultDepth 24
    SubSection "Display"
        Depth   24
        Modes   "1920x1080"
    EndSubSection
EndSection
EOF
# ===== 5. Start Dummy X + LXDE =====
echo "[+] Starting Dummy X Server..."
sudo Xorg :0 -config /etc/X11/xorg.conf.d/xorg.conf -configdir /etc/X11/xorg.conf.d vt7 &
sleep 5
export DISPLAY=:0
echo "[+] Starting LXDE..."
lxsession &
sleep 5
# ===== 6. Start Sunshine in Screen =====
echo "[+] Launching Sunshine in a 'screen' session..."
screen -dmS sunshine bash -c 'DISPLAY=:0 sunshine'
screen -dmS cloudflared bash -c 'cloudflared tunnel --no-tls-verify --url https://localhost:47990 > /tmp/cloudflared.log 2>&1'
sleep 5  # wait a bit for cloudflared to initialize
TUNNEL_URL=$(grep -o 'https://[^ ]*\.trycloudflare\.com' /tmp/cloudflared.log |
head -n 1)
echo "Tunnel URL: $TUNNEL_URL"
