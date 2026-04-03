#!/bin/bash

set -e  # stop on error

APP_DIR="/opt/easyocr-service"
SERVICE_FILE="/etc/systemd/system/easyocr.service"
USER_NAME="opc"

echo "🚀 Starting EasyOCR setup..."

# 1. Install system dependencies
echo "📦 Installing system dependencies..."
sudo dnf install -y python3 python3-pip python3-devel \
    gcc gcc-c++ make \
    libXext libXrender libSM \
    mesa-libGL glib2

# 2. Create app directory if not exists
echo "📁 Creating app directory..."
sudo mkdir -p $APP_DIR
sudo chown -R $USER_NAME:$USER_NAME $APP_DIR

# 3. Copy app files (assumes you run script from project folder)
echo "📂 Copying app files..."
cp app.py $APP_DIR/
cp -r __pycache__ $APP_DIR/ 2>/dev/null || true

cd $APP_DIR

# 4. Create virtualenv if not exists
if [ ! -d "venv" ]; then
    echo "🐍 Creating virtual environment..."
    python3 -m venv venv
fi

# 5. Activate venv
source venv/bin/activate

# 6. Install Python dependencies
echo "📚 Installing Python dependencies..."
pip install --upgrade pip

pip install easyocr opencv-python pillow numpy fastapi uvicorn \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cpu

# 7. Fix permissions (important for systemd)
chmod +x venv/bin/uvicorn || true

# 8. Create/Update systemd service
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
sleep 2
curl -s http://127.0.0.1:8000/health || echo "Health check failed"

echo "✅ Setup complete!"