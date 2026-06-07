#!/bin/bash
#############################################
# REQUIRED INPUTS (from Argo / Recipe)
#############################################
# NAMESPACE: target Kubernetes namespace
# PASSWORD: password for Postgres

set -euo pipefail
source /scripts/lib/setup-kubeconfig.sh

POD=$(kubectl get pod -n "${NAMESPACE}" \
  -l app.kubernetes.io/name=postgresql \
  -o jsonpath='{.items[0].metadata.name}')

# FUNZIONE CORRETTA: passa il SQL via stdin evitando i conflitti di virgolette
psql_cmd() {
  kubectl exec -i -n "${NAMESPACE}" "${POD}" -- \
    env PGPASSWORD="${PASSWORD}" psql -U postgres postgres -c "$1"
}

echo "▸ PostgreSQL bootstrap"

echo "  → Creating demo schema..."
psql_cmd "CREATE SCHEMA IF NOT EXISTS demo;"
echo "  ✓ Schema 'demo' created"
echo "  → Creating demo tables..."
psql_cmd "CREATE TABLE IF NOT EXISTS demo.users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(255) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);"
echo "  ✓ Demo table created"

echo "✓ PostgreSQL bootstrap complete"