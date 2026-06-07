#!/bin/bash
#############################################
# REQUIRED INPUTS (from Argo / Recipe)
#############################################
# NAMESPACE: target Kubernetes namespace
# PG_HOST: Postgres host
# PG_DB: Postgres database
# PG_USER: Postgres user
# PG_PASSWORD: Postgres password
# REDIS_HOST: Redis host
# REDIS_PASSWORD: Redis password
# SYNC_INTERVAL: Seconds between synchonization
# IMAGE: Image used for integrate 
set -euo pipefail
source /scripts/lib/setup-kubeconfig.sh

echo "▸ Deploying postgres-redis-sync in namespace: ${NAMESPACE}"

#############################################
# NAMESPACE
#############################################

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

#############################################
# RENDER DEPLOYMENT
#############################################

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-redis-sync
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres-redis-sync
  template:
    metadata:
      labels:
        app: postgres-redis-sync
    spec:
      containers:
        - name: sync
          image: ${IMAGE}
          env:
            - name: PG_HOST
              value: "${PG_HOST}"
            - name: PG_DB
              value: "${PG_DB}"
            - name: PG_USER
              value: "${PG_USER}"
            - name: PG_PASSWORD
              value: "${PG_PASSWORD}"

            - name: REDIS_HOST
              value: "${REDIS_HOST}"
            - name: REDIS_PASSWORD
              value: "${REDIS_PASSWORD}"

            - name: SYNC_INTERVAL
              value: "${SYNC_INTERVAL}"
EOF

#############################################
# DONE
#############################################

echo "✓ postgres-redis-sync deployed successfully"