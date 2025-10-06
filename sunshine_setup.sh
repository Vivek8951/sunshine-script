#!/bin/bash
set -euo pipefail

# Colors
CYAN='\033[0;36m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

# Banner
echo -e "${PURPLE}${BOLD}"
echo -e "${CYAN}
 
 ______              _         _                                             
|  ___ \\            | |       | |                   _                        
| |   | |  ___    _ | |  ____ | | _   _   _  ____  | |_   ____   ____  _____ 
| |   | | / _ \\  / || | / _  )| || \\ | | | ||  _ \\ |  _) / _  ) / ___)(___  )
| |   | || |_| |( (_| |( (/ / | | | || |_| || | | || |__( (/ / | |     / __/ 
|_|   |_| \\___/  \\____| \\____)|_| |_| \\____||_| |_| \\___)\\____)|_|    (_____)                   
                                
                                                                                                                              
${YELLOW}                      :: Powered by Noderhunterz ::
${RESET}"
echo

# === 1. Install dependencies ===
echo "[+] Installing dependencies..."
sudo apt update
sudo apt install -y \
  xserver-xorg-video-dummy \
  lxde-core lxde-common lxsession \
  screen curl unzip wget ufw

# === 2. Kill existing related processes (safe) ===
echo "[+] Stopping existing services/processes (if any)..."
# Use pgrep and pkill safely
for p in sunshine cloudflared lxsession lxpanel openbox; do
  if pgrep -x "$p" >/dev/null 2>&1; then
    echo "Killing ${p}..."
    pkill -9 -x "$p" || true
  fi
done

# kill Xorg instances on display :0 if present
if pgrep -f "Xorg :0" >/dev/null 2>&1 || pgrep -f "Xorg.*vt7" >/dev/null 2>&1; then
  echo "Killing Xorg(:0 / vt7) processes..."
  pkill -f "Xorg :0" || true
  pkill -f "Xorg.*vt7" || true
fi

# kill screen sessions named sunshine or cloudflared
screen -ls 2>/dev/null | awk '/\t/ {print $1}' | while read -r session; do
  if echo "$session" | grep -qiE 'sunshine|cloudflared'; then
    echo "Killing screen session $session"
    screen -S "$session" -X quit || true
  fi
done

# === 3. Install Sunshine (if missing) ===
if ! command -v sunshine >/dev/null 2>&1; then
  echo "[+] Installing Sunshine (.deb if available)..."
  # try to download an apt .deb (user may change version if needed)
  TMPDEB="/tmp/sunshine.deb"
  rm -f "$TMPDEB"
  # NOTE: change URL if you have a specific working version. Using a placeholder pattern.
  # If this fails, the script will continue and we handle running a missing sunshine binary gracefully.
  if wget -q -O "$TMPDEB" "https://github.com/LizardByte/Sunshine/releases/latest/download/sunshine-ubuntu-22.04-amd64.deb"; then
    sudo apt install -y "$TMPDEB" || true
    rm -f "$TMPDEB"
  else
    echo "Could not download sunshine .deb automatically. Please download a compatible .deb manually."
  fi
else
  echo "[*] Sunshine already installed."
fi

# === 4. Firewall ===
echo "[+] Configuring firewall for SSH & Sunshine..."
sudo ufw allow ssh
sudo ufw allow 47984/tcp
sudo ufw allow 47989/tcp
sudo ufw allow 48010/tcp
sudo ufw allow 47990/tcp
sudo ufw allow 47998:48002/udp
sudo ufw --force enable

# === 5. Install Cloudflared (if missing) ===
if ! command -v cloudflared >/dev/null 2>&1; then
  echo "[+] Installing Cloudflared..."
  TMP_CF="/tmp/cloudflared.deb"
  wget -q -O "$TMP_CF" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb" || true
  if [ -f "$TMP_CF" ]; then
    sudo apt install -y "./$TMP_CF" || true
    rm -f "$TMP_CF"
  else
    echo "Could not fetch cloudflared .deb automatically. Please install cloudflared manually."
  fi
else
  echo "[*] Cloudflared already installed."
fi

# === 6. Configure dummy X server (write a single /etc/X11/xorg.conf for dummy) ===
echo "[+] Writing dummy Xorg config..."
sudo mkdir -p /etc/X11/xorg.conf.d

sudo tee /etc/X11/xorg.conf > /dev/null <<'EOF'
Section "Device"
    Identifier  "Configured Video Device"
    Driver      "dummy"
    VideoRam    256000
EndSection

Section "Monitor"
    Identifier  "Configured Monitor"
    HorizSync   28.0-80.0
    VertRefresh 48.0-75.0
EndSection

Section "Screen"
    Identifier  "Default Screen"
    Device      "Configured Video Device"
    Monitor     "Configured Monitor"
    DefaultDepth 24
    SubSection "Display"
        Depth   24
        Modes   "1920x1080"
    EndSubSection
EndSection
EOF

# optional: avoid writing /dev/uinput references if uinput isn't available
if [ -w /dev/uinput ] || [ -e /dev/uinput ]; then
  echo "[+] uinput device present"
else
  echo "[!] /dev/uinput not present or not writable — script will run Sunshine without uinput."
fi

# === 7. Start Dummy X and LXDE ===
echo "[+] Starting Dummy X server..."
# Use a screen to keep Xorg backgrounded and avoid needing vt switching if not available
sudo Xorg :0 -config /etc/X11/xorg.conf -configdir /etc/X11/xorg.conf.d vt7 >/tmp/xorg.log 2>&1 &

sleep 4
export DISPLAY=:0

echo "[+] Starting LXDE session (lxsession)..."
# start LXDE in background; if it fails, script continues
lxsession >/tmp/lxsession.log 2>&1 & || true
sleep 3

# === 8. Start Sunshine in screen (handle no-uinput on VPS) ===
SUNSHINE_CMD="sunshine"
# if sunshine binary missing, try to find an extracted folder
if ! command -v sunshine >/dev/null 2>&1; then
  if [ -x "$HOME/sunshine-linux-x86_64/sunshine" ]; then
    SUNSHINE_CMD="$HOME/sunshine-linux-x86_64/sunshine"
  fi
fi

# If /dev/uinput is missing or not writable, add --no-uinput
if [ ! -w /dev/uinput ] && [ ! -e /dev/uinput ]; then
  SUNSHINE_CMD="$SUNSHINE_CMD --no-autostart --no-uinput --config-dir ~/.config/sunshine"
else
  SUNSHINE_CMD="$SUNSHINE_CMD --no-autostart --config-dir ~/.config/sunshine"
fi

# Ensure config dir exists
mkdir -p ~/.config/sunshine

echo "[+] Launching Sunshine in a detached screen session..."
screen -dmS sunshine bash -lc "DISPLAY=:0 $SUNSHINE_CMD > /tmp/sunshine.log 2>&1 || true"

# === 9. Launch cloudflared tunnel (try to capture trycloudflare URL) ===
echo "[+] Launching cloudflared in screen..."
# example: mapping to general Sunshine port (change if you use different)
screen -dmS cloudflared bash -lc "cloudflared tunnel --no-tls-verify --url https://localhost:47990 > /tmp/cloudflared.log 2>&1 || true"

# Wait a few seconds and try to capture the tunnel URL (if cloudflared created one)
sleep 6
TUNNEL_URL=$(grep -o 'https://[^ ]*\.trycloudflare\.com' /tmp/cloudflared.log | head -n 1 || true)
if [ -n "$TUNNEL_URL" ]; then
  echo "Tunnel URL: $TUNNEL_URL"
else
  echo "No trycloudflare URL detected in /tmp/cloudflared.log (it may require login or manual tunnel creation). Check /tmp/cloudflared.log"
fi

echo "[+] Setup script completed. Check logs: /tmp/xorg.log /tmp/lxsession.log /tmp/sunshine.log /tmp/cloudflared.log"
