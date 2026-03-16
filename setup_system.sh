#!/bin/bash
set -e

echo "============================================================"
echo "    NovaOps - Judge Environment Setup"
echo "============================================================"
echo "This script prepares the NovaOps environment for evaluation"
echo "without starting the live simulation."
echo ""

# Function to check for binary or alias
check_cmd() {
    if command -v "$1" &> /dev/null; then
        return 0
    elif [ "$1" == "kubectl" ] && minikube kubectl &> /dev/null; then
        echo "ℹ️  Using 'minikube kubectl' as fallback for kubectl."
        alias kubectl='minikube kubectl'
        return 0
    else
        return 1
    fi
}

# 1. Check for system dependencies
echo "🔍 Checking for required binaries..."
for cmd in docker minikube python3; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Error: $cmd is not installed. Please install it to proceed."
        exit 1
    fi
    echo "✅ $cmd found."
done

if ! command -v kubectl &> /dev/null; then
    echo "⚠️  kubectl not found. Attempting to use minikube's built-in kubectl..."
    # We will use 'minikube kubectl --' for all kubectl commands later
    KUBECTL_CMD="minikube kubectl --"
else
    echo "✅ kubectl found."
    KUBECTL_CMD="kubectl"
fi

# 2. Setup Python environment
echo "🐍 Setting up Python virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 3. Pre-pulling/Building images to save time during demo
echo "🐳 Pre-pulling core Docker images..."
docker pull localstack/localstack:latest
docker pull python:3.10-slim

# 4. Pre-warming Minikube
echo "🚀 Initializing Minikube (this may take a minute)..."
# We start it to ensure the VM/Container is created and basic images are pulled
minikube start --driver=docker
eval $(minikube docker-env)

echo "📦 Building dummy-service image inside Minikube..."
docker build -t dummy-service:latest ./dummy-service

echo "🛑 Stopping Minikube to leave system in clean state..."
minikube stop

echo ""
echo "============================================================"
echo "✅ SETUP COMPLETE"
echo "============================================================"
echo "The NovaOps environment is now primed and ready for users."
echo "To start the system, follow the OPERATIONAL_VALIDATION.md"
echo "beginning with './start_war_room.sh'."
echo "============================================================"
