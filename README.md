# Sunshine + Dummy Xorg + LXDE + Cloudflared Setup Script

This script automates the setup of a **Sunshine** stream server with a virtual display and secure remote access via Cloudflare Tunnel, ideal for headless Linux systems without GPU or physical display hardware.

---

##  Features

-  Installs **LXDE** desktop + `xserver-xorg-video-dummy` for virtual display
-  Installs **Sunshine** game streaming and **Cloudflared** for tunneling
-  Sets up **dummy keyboard and mouse** input devices so Moonlight streaming works
-  Configures **UFW firewall rules** for all necessary Sunshine ports
-  Launches all services (Xorg, LXDE, Sunshine, Cloudflared) in background `screen` sessions
-  Safely kills any existing conflicting processes before starting fresh
-  Displays a working **public Cloudflare Tunnel URL** for remote access

---


Run these commands as root to create a new user and give them sudo access:

# Create user (replace myuser with any name you want)
```bash
sudo adduser myuser
```

# Add user to sudo group
```bash
sudo usermod -aG sudo myuser
```

# Switch to new user
```bash
su - myuser
```

##  Usage

1. Clone or download this script into your server:

    ```bash
    bash <(curl -sL https://raw.githubusercontent.com/CodeDialect/sunshine-script/main/sunshine_setup.sh)
    ```

2. After installation, the script will display a **Cloudflare Tunnel URL**:

    ```
    Tunnel URL: https://xyz123.trycloudflare.com
    ```

3. Open this URL in your browser to access the Sunshine Web UI and pair with Moonlight.

---

##  What It Installs

- `lxde-core`, `lxsession`: Lightweight desktop environment  
- `xserver-xorg-video-dummy`: Virtual display driver  
- `sunshine-ubuntu-22.04-amd64.deb`: Sunshine streaming server  
- `cloudflared-linux-amd64.deb`: Cloudflare Tunnel  
- `ufw`: Firewall to secure your instance  

It also installs `screen`, `curl`, `wget`, and utilities needed for setup and logging.

---

##  Benefits

- **No physical GPU or monitor needed**  
- **Secure remote streaming** over Cloudflare without exposing ports  
- **Plug-and-play** — just one script, no manual setup steps  
- **Good for VPS environments and gameserver setups** where input forwarding and streaming are required

---

##  Troubleshooting

- If **Sunshine Web UI fails to load**, ensure the dummy desktop is working (`lxsession` should be running).
- If **Cloudflared tunnel exits early**, run it manually to debug:

    ```bash
    cloudflared tunnel --no-tls-verify --url https://localhost:47990
    ```

- If **keyboard/mouse input isn't working**, ensure `/dev/uinput` exists and input drivers are loaded (e.g. `xserver-xorg-input-evdev`).

---
