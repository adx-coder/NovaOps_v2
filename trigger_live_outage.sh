#!/bin/bash
set -e

echo "🚀 Starting Live Simulation..."

# Function to wrap kubectl calls with k3s docker container 
kubectl() {
    docker compose exec -T k3s kubectl "$@"
}

echo "🔍 Checking if K3s is running..."
if ! docker compose ps | grep -q "k3s"; then
    echo "❌ K3s container is not running. Please run ./start_war_room.sh first."
    exit 1
fi

echo "📦 Building dummy-service..."
docker build -t dummy-service:latest ./dummy-service
echo "📥 Importing image into K3s..."
docker save dummy-service:latest | docker compose exec -T k3s ctr images import -

echo "🚀 Deploying dummy-service to Kubernetes..."
cat dummy-service/k8s.yaml | kubectl apply -f -

echo "⏳ Waiting for dummy-service pod to be ready..."
kubectl wait --for=condition=ready pod -l app=dummy-service --timeout=120s

echo "💥 Forcing Memory Leak (OOM) inside dummy-service..."
kubectl run tmp-curl --rm -i --restart=Never --image=curlimages/curl -- \
    sh -c 'for i in $(seq 1 15); do curl -s http://dummy-service:8080/memory-leak > /dev/null || true; sleep 0.5; done'

sleep 3

echo "💀 OOM Leak successful. dummy-service pod should be CrashLoop-ing now."

echo "🕵️‍♀️  Starting Live NovaOps Agent to detect and analyze the OOM..."
# In a pure dockerized setup the run_live_agent wouldn't rely on local python venv, 
# it can rely on the python runtime from novaops-api docker container instead
docker compose exec -T novaops-api python run_live_agent.py

echo "🎉 Live simulation script completed."
