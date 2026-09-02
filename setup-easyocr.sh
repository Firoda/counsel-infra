#!/bin/bash

set -e

APP_DIR="/opt/easyocr-service"
SERVICE_FILE="/etc/systemd/system/easyocr.service"
USER_NAME="opc"

echo "🚀 Starting EasyOCR setup..."

# 1. Install system dependencies
echo "📦 Installing system dependencies..."
sudo dnf install -y python3 python3-pip python3-devel \
    gcc gcc-c++ make \
    libXext libXrender libSM \
    mesa-libGL glib2 \
    policycoreutils-python-utils

# 2. Create app directory
echo "📁 Setting up application directory..."
sudo mkdir -p $APP_DIR
sudo chown -R $USER_NAME:$USER_NAME $APP_DIR

# 3. Copy app files (run script from project root)
echo "📂 Copying app files..."
cp app.py $APP_DIR/

cd $APP_DIR

# 4. Create virtualenv as opc user (IMPORTANT)
if [ ! -d "venv" ]; then
    echo "🐍 Creating virtual environment..."
    sudo -u $USER_NAME python3 -m venv venv
fi

# 5. Install dependencies as opc
echo "📚 Installing Python dependencies..."
sudo -u $USER_NAME bash <<EOF
source venv/bin/activate
pip install --upgrade pip
pip install transformers opencv-python pillow numpy fastapi uvicorn
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
EOF

# 6. Ensure correct ownership (critical)
echo "🔐 Fixing permissions..."
sudo chown -R $USER_NAME:$USER_NAME $APP_DIR
sudo chmod -R 755 $APP_DIR

# 7. Fix SELinux context (CRITICAL FIX)
echo "🛡️ Configuring SELinux context..."
sudo semanage fcontext -a -t bin_t "$APP_DIR/venv(/.*)?" 2>/dev/null || true
sudo restorecon -Rv $APP_DIR/venv

# 8. Create systemd service
echo "⚙️ Configuring systemd service..."
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=EasyOCR Captcha Service
After=network.target

[Service]
User=$USER_NAME
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python -m uvicorn app:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

# 9. Reload and start service
echo "🔄 Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable easyocr
sudo systemctl restart easyocr

# 10. Verify
echo "🔍 Checking service status..."
sudo systemctl status easyocr --no-pager

echo "🌐 Health check..."
sleep 5
curl -s http://127.0.0.1:8000/health || echo "Health check failed"

echo "✅ Setup complete!"
