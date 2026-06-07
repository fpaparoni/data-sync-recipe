#!/bin/bash

#############################################
# REQUIRED INPUTS (from Argo / Recipe)
#############################################
# POSTGRES_NAMESPACE: target Postgres namespace
# REDIS_NAMESPACE: target Redis namespace
# PG_USER: Postgres username
# PG_PASSWORD: Postgres password
# PG_DATABASE: Postgres database name
# REDIS_PASSWORD: Redis password
#############################################

set -euo pipefail

source /scripts/lib/setup-kubeconfig.sh

: "${POSTGRES_NAMESPACE:?missing POSTGRES_NAMESPACE}"
: "${REDIS_NAMESPACE:?missing REDIS_NAMESPACE}"
: "${PG_USER:?missing PG_USER}"
: "${PG_PASSWORD:?missing PG_PASSWORD}"
: "${PG_DATABASE:?missing PG_DATABASE}"
: "${REDIS_PASSWORD:?missing REDIS_PASSWORD}"

echo "▸ Smoke test Postgres(${POSTGRES_NAMESPACE}) → Redis(${REDIS_NAMESPACE})"

#############################################
# POD DISCOVERY
#############################################

PG_POD=$(kubectl get pod -n "${POSTGRES_NAMESPACE}" \
  -l app.kubernetes.io/name=postgresql \
  -o jsonpath='{.items[0].metadata.name}')

REDIS_POD=$(kubectl get pod -n "${REDIS_NAMESPACE}" \
  -l app.kubernetes.io/name=redis \
  -o jsonpath='{.items[0].metadata.name}')

if [[ -z "${PG_POD}" || -z "${REDIS_POD}" ]]; then
  echo "❌ Cannot find Postgres or Redis pods"
  exit 1
fi

echo "✔ Postgres pod: ${PG_POD}"
echo "✔ Redis pod: ${REDIS_POD}"

#############################################
# TEST DATA
#############################################

TEST_USER="smoke_$(date +%s)"
TEST_EMAIL="${TEST_USER}@test.local"

echo "▸ Creating test user: ${TEST_USER}"

#############################################
# INSERT INTO POSTGRES
#############################################

kubectl exec -n "${POSTGRES_NAMESPACE}" "${PG_POD}" -- \
  env PGPASSWORD="${PG_PASSWORD}" \
  psql \
  -U "${PG_USER}" \
  -d "${PG_DATABASE}" \
  -c "INSERT INTO demo.users (username,email) VALUES ('${TEST_USER}','${TEST_EMAIL}')"

#############################################
# FETCH GENERATED ID
#############################################

USER_ID=$(
kubectl exec -n "${POSTGRES_NAMESPACE}" "${PG_POD}" -- \
  env PGPASSWORD="${PG_PASSWORD}" \
  psql \
  -U "${PG_USER}" \
  -d "${PG_DATABASE}" \
  -t -A \
  -c "SELECT id FROM demo.users WHERE username='${TEST_USER}'"
)

USER_ID=$(echo "${USER_ID}" | tr -d '[:space:]')

if [[ -z "${USER_ID}" ]]; then
  echo "❌ Cannot retrieve generated user id"
  exit 1
fi

echo "✔ Generated ID: ${USER_ID}"

#############################################
# WAIT FOR REDIS SYNC
#############################################

echo "▸ Waiting for Redis sync..."

FOUND=0

for i in {1..20}; do

  VALUE=$(
    kubectl exec -n "${REDIS_NAMESPACE}" "${REDIS_POD}" -- \
      redis-cli -a "${REDIS_PASSWORD}" \
      GET "user:${USER_ID}" 2>/dev/null || true
  )

  if echo "${VALUE}" | grep -q "${TEST_USER}"; then
    FOUND=1
    break
  fi

  echo "  retry ${i}/20..."
  sleep 2
done

#############################################
# ASSERT
#############################################

if [[ "${FOUND}" != "1" ]]; then
  echo "❌ FAILED: Postgres → Redis sync not working"
  exit 1
fi

#############################################
# CLEANUP
#############################################

kubectl exec -n "${REDIS_NAMESPACE}" "${REDIS_POD}" -- \
  redis-cli -a "${REDIS_PASSWORD}" \
  DEL "user:${USER_ID}" >/dev/null 2>&1 || true

echo "✓ SMOKE TEST PASSED"