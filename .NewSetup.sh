#!/bin/bash
# setup.sh — Docker group activation + make scripts executable
# Run with: bash setup.sh
 
set -e
 
# ── 1. Add current user to the docker group (if not already) ──────────────────
if getent group docker > /dev/null 2>&1; then
  if id -nG "$USER" | grep -qw docker; then
    echo "✔ $USER is already in the docker group."
  else
    echo "➕ Adding $USER to the docker group..."
    sudo usermod -aG docker "$USER"
    echo "✔ Done."
  fi
else
  echo "⚠ Docker group not found. Is Docker installed?"
  exit 1
fi
 
# ── 2. Make all .sh files in the current directory executable ─────────────────
echo ""
echo "🔧 Making .sh scripts executable in: $(pwd)"
found=0
for f in *.sh; do
  [ -f "$f" ] || continue
  chmod +x "$f"
  echo "  ✔ chmod +x $f"
  found=1
done
if [ "$found" -eq 0 ]; then
  echo "  (no .sh files found in current directory)"
fi
 
# ── 3. Apply docker group to current shell session (no logout needed) ─────────
echo ""
echo "🐳 Activating docker group in this shell session..."
echo "   (your terminal will now re-launch with the docker group applied)"
echo ""
 
newgrp docker
