#!/bin/bash

# =============================================================================
# Calendar Deployment Script (Idempotent)
# =============================================================================
#
# USAGE:
#   1. Make executable: chmod +x deploy.sh
#   2. Run as root:
#      ./deploy.sh <cloudflare-tunnel-token>
#
#   Interactive prompts (in order):
#      - Git user name
#      - Git user email
#      - Tunnel domain (e.g., dev-app.yourdomain.com)
#      - Admin password (press Enter to keep existing or use default)
#      - /root/id_rsa (your SSH private key for GitHub)
#
# CAN BE RUN MULTIPLE TIMES SAFELY (Idempotent):
#   - Stops existing systemd services gracefully to release locks
#   - Backs up your configuration (.env.local and src/users.json) locally via /tmp
#   - Recursively deletes the working directory and pulls entirely fresh code
#   - Generates SHA-256 hashed passwords & restores your setups seamlessly
#   - Runs Vite in secured production mode (`vite build` + `vite preview`)
#   - Overwrites and restarts all systemd services with the latest architecture
#
# SERVICE MANAGEMENT:
#   systemctl status vite-frontend | wrangler-backend | cloudflare-tunnel
#   journalctl -u <service-name> -f  # View logs
#   systemctl restart <service-name>  # Restart a service
#
# =============================================================================

# Don't exit on error - we handle failures gracefully
# set -e

APP_DIR_FULL="$HOME/persian-calendar"
REPO_URL="https://github.com/AtypicalSysAdmin/persian-calendar.git"
APP_DIR="persian-calendar"

# Tunnel domain and name
echo ""
read -p "Enter your tunnel domain (e.g., calendar.yourdomain.com): " TUNNEL_DOMAIN

# Check for existing tunnel credentials to skip creation
EXISTING_CRED=""
if [ -d "$HOME/.cloudflared" ]; then
  EXISTING_CRED=$(ls $HOME/.cloudflared/*.json 2>/dev/null | head -n 1)
fi

if [ ! -z "$EXISTING_CRED" ]; then
  TUNNEL_NAME=$(basename "$EXISTING_CRED" .json)
  echo "   Found existing local tunnel credentials ($TUNNEL_NAME). Skipping tunnel setup..."
else
  echo ""
  read -p "Enter a NEW unique tunnel name (e.g., calendar-tunnel): " TUNNEL_NAME
  if [ -z "$TUNNEL_NAME" ]; then
    TUNNEL_NAME="calendar-tunnel"
  fi
fi

echo ""
read -s -p "Enter admin password (press Enter to keep existing or use default): " ADMIN_PASSWORD
echo ""

echo ""
echo "0. Checking disk space..."
DISK_MIN=500
AVAILABLE=$(df -BM "$HOME" | awk 'NR==2 {print $4}' | tr -d 'M')
if [ "$AVAILABLE" -lt "$DISK_MIN" ]; then
  echo "Error: Insufficient disk space. Need ${DISK_MIN}MB, have ${AVAILABLE}MB"
  exit 1
fi

echo "1. Updating system packages..."
apt update -y 2>/dev/null || true
apt upgrade -y 2>/dev/null || true

echo "2. Installing Git, Curl, and Wget..."
apt install -y git curl wget 2>/dev/null || true

echo "2.5. Configuring Git..."
if ! git config --global user.name > /dev/null 2>&1; then
  echo ""
  read -p "Enter your Git user name: " GIT_USER_NAME
  git config --global user.name "$GIT_USER_NAME"
fi

if ! git config --global user.email > /dev/null 2>&1; then
  echo ""
  read -p "Enter your Git user email: " GIT_USER_EMAIL
  git config --global user.email "$GIT_USER_EMAIL"
fi

echo "3. Installing Node.js 20 LTS..."
if ! command -v node &> /dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt install -y nodejs
else
  echo "   Node.js already installed, skipping..."
fi

echo "4. Installing Cloudflare Tunnel (cloudflared)..."
if ! command -v cloudflared &> /dev/null; then
  curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  DEBIAN_FRONTEND=noninteractive dpkg -i cloudflared.deb
  rm -f cloudflared.deb
else
  echo "   cloudflared already installed, skipping..."
fi

echo "4.5. Authenticating and creating Cloudflare Tunnel..."
if [ ! -f "$HOME/.cloudflared/cert.pem" ] && [ ! -f "/root/.cloudflared/cert.pem" ]; then
  echo "   ==============================================================="
  echo "   ATTENTION: You need to authenticate with Cloudflare."
  echo "   Please click/copy the URL below and authorize the tunnel."
  echo "   ==============================================================="
  cloudflared tunnel login
fi

if [ -z "$EXISTING_CRED" ]; then
  echo "   Creating tunnel '${TUNNEL_NAME}'..."
  cloudflared tunnel create ${TUNNEL_NAME} 2>/dev/null || true
else
  echo "   Using existing tunnel credentials..."
fi

echo "5. Cloning repository..."
# Handle dirty or existing repo by removing and re-cloning
if [ -d "$APP_DIR" ]; then
  echo "   Backing up configuration..."
  mkdir -p /tmp/persian-calendar-backup
  [ -f "$APP_DIR/src/users.json" ] && cp "$APP_DIR/src/users.json" /tmp/persian-calendar-backup/
  [ -f "$APP_DIR/.env.local" ] && cp "$APP_DIR/.env.local" /tmp/persian-calendar-backup/

  echo "   Stopping existing services to release locks..."
  systemctl stop vite-frontend wrangler-backend cloudflare-tunnel 2>/dev/null || true

  echo "   Removing existing repository for clean clone..."
  rm -rf "$APP_DIR"
fi

# Clone the repository using inline SSH key config
echo "   Cloning via SSH with key at /root/id_rsa..."
if ! git clone git@github.com:AtypicalSysAdmin/persian-calendar.git "$APP_DIR" --config core.sshCommand="ssh -i /root/id_rsa -o StrictHostKeyChecking=no" 2>&1; then
  echo "Error: Clone failed. Check your SSH key and GitHub deploy keys."
  exit 1
fi
cd "$APP_DIR"

echo "6. Installing project dependencies..."
npm install 2>/dev/null || npm ci 2>/dev/null || true

echo "6.5. Configuring environment and users..."

if [ -d "/tmp/persian-calendar-backup" ]; then
  echo "   Restoring previous configuration..."
  [ -f "/tmp/persian-calendar-backup/.env.local" ] && cp /tmp/persian-calendar-backup/.env.local .env.local
  [ -f "/tmp/persian-calendar-backup/users.json" ] && cp /tmp/persian-calendar-backup/users.json src/users.json
  rm -rf /tmp/persian-calendar  -backup
fi

if [ ! -f ".env.local" ] && [ -f ".env.example" ]; then
  cp .env.example .env.local
  echo "   Copied .env.example to .env.local"
fi

if [ ! -z "$ADMIN_PASSWORD" ]; then
  if [ -f "src/users.example.json" ]; then
    ADMIN_HASH=$(node -e "console.log(crypto.createHash('sha256').update('$ADMIN_PASSWORD').digest('hex'))")
    sed "s/8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918/$ADMIN_HASH/" src/users.example.json > src/users.json
    echo "   Admin password explicitly configured in src/users.json"
  fi
elif [ ! -f "src/users.json" ] && [ -f "src/users.example.json" ]; then
  cp src/users.example.json src/users.json
  echo "   Using default admin configuration (admin / admin)"
fi

echo "7. Creating Systemd Service Files..."

# Vite Frontend Service
echo "   Creating vite-frontend.service..."
tee /etc/systemd/system/vite-frontend.service > /dev/null <<EOF
[Unit]
Description=Vite Frontend Service
After=network.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR_FULL}
ExecStartPre=${APP_DIR_FULL}/node_modules/.bin/vite build
ExecStart=${APP_DIR_FULL}/node_modules/.bin/vite preview --port 5173 --host
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Wrangler Backend Service
echo "   Creating wrangler-backend.service..."
tee /etc/systemd/system/wrangler-backend.service > /dev/null <<EOF
[Unit]
Description=Wrangler Backend Worker
After=network.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR_FULL}
ExecStart=${APP_DIR_FULL}/node_modules/.bin/wrangler dev
Environment=NODE_ENV=development
Environment=CI=true
Environment=WRANGLER_SEND_METRICS=false
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Cloudflare Tunnel Service
echo "   Creating cloudflare-tunnel.service..."
tee /etc/systemd/system/cloudflare-tunnel.service > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
ExecStartPre=-/usr/bin/cloudflared tunnel route dns ${TUNNEL_NAME} ${TUNNEL_DOMAIN}
ExecStart=/usr/bin/cloudflared tunnel run --url http://localhost:5173 ${TUNNEL_NAME}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "8. Enabling and Starting All Services..."
systemctl daemon-reload
systemctl enable vite-frontend 2>/dev/null || true
systemctl enable wrangler-backend 2>/dev/null || true
systemctl enable cloudflare-tunnel 2>/dev/null || true
systemctl restart vite-frontend 2>/dev/null || systemctl start vite-frontend 2>/dev/null || true
systemctl restart wrangler-backend 2>/dev/null || systemctl start wrangler-backend 2>/dev/null || true
systemctl restart cloudflare-tunnel 2>/dev/null || systemctl start cloudflare-tunnel 2>/dev/null || true

echo ""
echo "========================================"
echo "Deployment complete!"
echo "Check status: systemctl status vite-frontend wrangler-backend cloudflare-tunnel"
echo "View logs: journalctl -u cloudflare-tunnel -f"
echo "========================================"

# Cleanup (none needed since we use key files directly, not temp copies)
echo ""