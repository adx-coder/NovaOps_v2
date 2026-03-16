#!/bin/bash
set -e

# ==============================================================================
# NovaOps - Zero-Install Global Start Script
# Spin up the entire system (Docker APIs + K3s Kubernetes) and pipe all stdout 
# to a single consolidated log file in the background.
# ==============================================================================

LOG_FILE="novaops_system.log"
PID_FILE=".system_pids"

# Clear out old logs and PIDs
rm -f "$LOG_FILE" "$PID_FILE"

echo "======================================" > "$LOG_FILE"
echo "    NovaOps System Logs - Started     " >> "$LOG_FILE"
echo "    Time: $(date)                     " >> "$LOG_FILE"
echo "======================================" >> "$LOG_FILE"

echo "🌟 Starting NovaOps System Ecosystem..."
echo "📂 All background logs are actively piping into: $LOG_FILE"
echo ""

# 1. Pre-Create Directories to Prevent Docker Root Ownership Issues
echo "📁 [1/2] Initializing required volume directories..."
mkdir -p ./plans ./runbooks ./logs
chmod 777 ./plans ./runbooks
# Ensure everyone can write to the log dir too
chmod 777 ./logs

# 2. Start Docker Backend (API + LocalStack + K3s)
echo "🐳 [2/2] Booting Kubernetes, Backend API, and AWS LocalStack (Docker)..."
# Ensure previous containers are stopped to avoid name conflicts
docker compose down >> "$LOG_FILE" 2>&1 || true
docker compose up -d --build >> "$LOG_FILE" 2>&1

echo "🔌 Rewriting Kubeconfig internal networking for API container..."
sleep 5  # Give k3s time to generate the config file
docker compose exec novaops-api sed -i 's/127.0.0.1/k3s/g' /root/.kube/config || true

# Tail Docker logs in the background and append them to our global log stream
docker compose logs -f >> "$LOG_FILE" 2>&1 &
DOCKER_LOG_PID=$!
echo "$DOCKER_LOG_PID" >> "$PID_FILE"

echo ""
echo "✅ System is fully online and ready!"
echo "   - Dashboard UI:    http://localhost:8082/dashboard/"
echo "   - API Swagger      http://localhost:8082/docs"
echo "   - K8s Cluster:     Running inside 'k3s' docker container"
echo ""
echo "🔥 Want to see the merged logs? Run: tail -f $LOG_FILE"
echo "🛑 Want to shut down cleanly?  Run: ./stop_war_room.sh"
echo ""
