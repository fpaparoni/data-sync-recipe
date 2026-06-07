#!/bin/bash
#############################################
# REQUIRED INPUTS (from Argo / Recipe)
#############################################
# NAMESPACE: target Kubernetes namespace
# PASSWORD: password for Redis
set -euo pipefail
source /scripts/lib/setup-kubeconfig.sh

POD=$(kubectl get pod -n "${NAMESPACE}" \
  -l app.kubernetes.io/name=redis,app.kubernetes.io/component=master \
  -o jsonpath='{.items[0].metadata.name}')

redis_cmd() {
  kubectl exec -n "${NAMESPACE}" "${POD}" -- \
    bash -c "redis-cli -a '${PASSWORD}' $1"
}

echo "▸ Redis bootstrap"

echo "  → Configuring keyspace notifications..."
redis_cmd "CONFIG SET notify-keyspace-events KEA"
echo "  ✓ Keyspace notifications enabled (KEA)"

echo "  → Setting eviction policy to allkeys-lru..."
redis_cmd "CONFIG SET maxmemory-policy allkeys-lru"
echo "  ✓ Eviction policy set to allkeys-lru"

echo "✓ Redis bootstrap complete"
