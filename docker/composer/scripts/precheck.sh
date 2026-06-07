#!/bin/bash
set -euo pipefail

# shellcheck source=setup-kubeconfig.sh
source /scripts/lib/setup-kubeconfig.sh

echo "╔══════════════════════════════════════════╗"
echo "║         COMPOSER — PRECHECK              ║"
echo "╚══════════════════════════════════════════╝"
echo ""

echo "▸ Checking cluster connectivity..."
kubectl cluster-info --request-timeout=15s
echo ""

echo "▸ Cluster nodes:"
kubectl get nodes --no-headers | awk '{printf "  ✓ %-40s %s\n", $1, $2}'
echo ""

echo "Precheck completed ✓"
