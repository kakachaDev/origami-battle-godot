#!/usr/bin/env bash
set -euo pipefail

GODOT="/home/dev/bin/godot4"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build/web"
NGINX_CONF="/etc/nginx/sites-available/origami-battle"
PORT=443

echo "==> Building Origami Battle for Web..."
mkdir -p "$BUILD_DIR"

"$GODOT" --headless --path "$PROJECT_DIR" --export-release "Web" "$BUILD_DIR/index.html"

echo "==> Build complete: $BUILD_DIR"

if [ ! -f "$NGINX_CONF" ]; then
    echo "==> ERROR: nginx not configured. Run once:"
    echo "    sudo cp $PROJECT_DIR/nginx-origami.conf $NGINX_CONF && sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/origami-battle && sudo nginx -t && sudo systemctl reload nginx"
    exit 1
fi

echo ""
echo "==> Done! Open: https://work.kakacha.space"
