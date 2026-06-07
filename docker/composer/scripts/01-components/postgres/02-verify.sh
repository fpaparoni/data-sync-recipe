#!/bin/bash
#############################################
# REQUIRED INPUTS (from Argo / Recipe)
#############################################
# NAMESPACE: target Kubernetes namespace
# PASSWORD: password for Postgres

set -euo pipefail
source /scripts/lib/setup-kubeconfig.sh

echo "▸ Verifying PostgreSQL in '${NAMESPACE}'..."

echo "  1/3 Waiting for pod readiness..."
kubectl wait pod -l app.kubernetes.io/name=postgresql -n "${NAMESPACE}" --for=condition=Ready --timeout=120s
echo "  ✓ Pod ready"

echo "  2/3 Checking service..."
kubectl get svc postgresql -n "${NAMESPACE}" --no-headers
echo "  ✓ Service exists"

echo "  3/3 Running SELECT 1..."
POD=$(kubectl get pod -n "${NAMESPACE}"           -l app.kubernetes.io/name=postgresql           -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n "${NAMESPACE}" "${POD}" --           bash -c "PGPASSWORD='${PASSWORD}' psql -U postgres -c 'SELECT 1' postgres"
echo "  ✓ Database reachable"

echo "✓ PostgreSQL verification passed"
