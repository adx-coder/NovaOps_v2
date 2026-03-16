#!/bin/bash
echo "🚀 Triggering 7 simulated incidents through Docker API..."
docker compose exec -T novaops-api python -m evaluation --all
