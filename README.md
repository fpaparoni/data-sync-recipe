# data-sync-recipe

> A reference implementation of a **stack installation workflow** using Argo Workflows —
> demonstrating how to install, verify, integrate and smoke-test a PostgreSQL + Redis
> data cache as a composable, declarative recipe.

This repository is the companion code for the article
[**The Missing Primitive: Orchestrating Cloud-Native Stacks Beyond GitOps**](https://medium.com/@fpaparoni/the-missing-primitive-orchestrating-cloud-native-stacks-beyond-gitops-16acd57956c2).

The core idea: Helm, ArgoCD, Flux and Terraform are each excellent at what they do,
but none of them can express a *recipe* — a multi-step, procedural workflow that
installs components, waits for readiness, wires them together, and verifies the result
end-to-end. That is what this prototype demonstrates.

---

## What it does

The workflow installs a **PostgreSQL + Redis data cache platform** on a running
Kubernetes cluster, in five automated steps:

```
precheck
    ↓
[parallel] lifecycle-postgres    lifecycle-redis
               ↓                      ↓
           install                 install
           verify (retry)          verify (retry)
           bootstrap               bootstrap
                    ↓         ↓
           configure-postgres-redis-cache
                         ↓
              smoke-test-cache-hit-miss
                         ↓
                  generate-report (onExit)
```

Each lifecycle has three phases: **install** (Helm), **verify** (readiness check with
retry/backoff), and **bootstrap** (seed data / initial configuration). The integration
step deploys a custom sync daemon that continuously mirrors `demo.users` rows from
PostgreSQL into Redis. The smoke test inserts a record into Postgres, waits for Redis
to reflect it, and asserts the result.

---

## Repository structure

```
data-sync-recipe/
├── argo-workflows/
│   ├── namespace.yaml                          # argo-workflows namespace
│   └── rbac/
│       ├── serviceaccount.yaml                 # composer-workflow-sa
│       └── clusterrolebinding.yaml
│
├── workflow/
│   └── datacache.yaml                          # The main Workflow (entrypoint)
│
├── workflowtemplates/
│   ├── 01-components/
│   │   ├── postgres.yaml                       # ClusterWorkflowTemplate: install/verify/bootstrap
│   │   └── redis.yaml                          # ClusterWorkflowTemplate: install/verify/bootstrap
│   ├── 02-integrations/
│   │   └── postgres-redis.yaml                 # ClusterWorkflowTemplate: deploys sync daemon
│   └── 03-smoke-tests/
│       └── data-cache-smoke-tests.yaml         # ClusterWorkflowTemplate: end-to-end cache test
│
├── docker/
│   ├── composer/                               # composer-tools image (kubectl + helm + scripts)
│   │   ├── Dockerfile
│   │   └── scripts/
│   │       ├── precheck.sh
│   │       ├── lib/setup-kubeconfig.sh
│   │       ├── 01-components/
│   │       │   ├── postgres/{01-install,02-verify,03-bootstrap}.sh
│   │       │   └── redis/{01-install,02-verify,03-bootstrap}.sh
│   │       ├── 02-integrations/
│   │       │   └── postgres-redis-cache/integrate.sh
│   │       └── 03-smoke-tests/
│   │           └── data-cache.sh
│   └── custom-components/
│       └── postgres-redis-sync/
│           ├── Dockerfile
│           └── sync.py                         # Python daemon: polls Postgres, writes to Redis
│
├── setup.sh                                    # Install Argo + apply all CWTs
├── teardown.sh                                 # Selective cleanup (--components/--framework/--argo/--all)
└── docker-build.sh                             # Build and push Docker images
```

---

## Prerequisites

- A running Kubernetes cluster (local or cloud)
- `kubectl` configured and pointing to the target cluster
- `helm` v3
- Docker (only if you need to rebuild the images)

The `setup.sh` script installs Argo Workflows itself, so no prior Argo installation
is required.

---

## Quickstart

**1. Install Argo Workflows and apply all ClusterWorkflowTemplates:**

```bash
bash setup.sh
```

If Argo Workflows is already installed on your cluster:

```bash
bash setup.sh --skip-argo
```

**2. Submit the workflow:**

```bash
kubectl create -f workflow/datacache.yaml
```

**3. Follow execution in the Argo UI:**

```bash
kubectl -n argo-workflows port-forward svc/argo-server 2746:2746
```

Then open [https://localhost:2746](https://localhost:2746).

**4. Teardown:**

```bash
bash teardown.sh --all         # remove everything
bash teardown.sh --components  # remove postgres/redis/sync only
bash teardown.sh --framework   # remove CWTs and workflow jobs only
bash teardown.sh --argo        # uninstall Argo Workflows only
```

---

## Key design concepts

### ClusterWorkflowTemplates as reusable primitives

Each component (Postgres, Redis) is defined as a `ClusterWorkflowTemplate` with three
named templates — `install`, `verify`, `bootstrap` — that the main workflow composes
via `templateRef`. This mirrors the idea of a recipe referencing named steps from a
shared library.

### Three-phase lifecycle per component

Every component goes through:

| Phase | What it does |
|---|---|
| `install` | `helm upgrade --install` with pinned version and storage config |
| `verify` | Waits for readiness via `pg_isready` / `redis-cli ping`, with retry/backoff (3 attempts, 30s base, factor 2) |
| `bootstrap` | Seeds initial schema and data (`demo.users` table in Postgres, test keys in Redis) |

### Custom sync daemon

`docker/custom-components/postgres-redis-sync/sync.py` is a lightweight Python daemon
that runs as a Kubernetes `Deployment` (deployed by the integration step). It polls
`demo.users` in Postgres every `SYNC_INTERVAL` seconds and writes each row as a JSON
value under `user:<id>` in Redis with a 1-hour TTL.

### End-to-end smoke test

The smoke test does not just check if pods are running. It:

1. Discovers the live Postgres and Redis pods by label selector
2. Inserts a uniquely named test user directly into Postgres via `kubectl exec`
3. Polls Redis up to 20 times (2s apart) waiting for `user:<id>` to appear
4. Asserts the value contains the expected username
5. Cleans up the test key from Redis

This verifies the full data path — Postgres write → sync daemon → Redis read — not
just component availability.

### onExit report

The workflow declares `onExit: generate-report`, which runs unconditionally after
success or failure and produces a summary of the workflow execution (recipe name,
status, namespace).

---

## Docker images

| Image | Purpose |
|---|---|
| `fpaparoni/composer-tools:2.0.1` | Base image for all workflow steps: `kubectl`, `helm`, all shell scripts |
| `fpaparoni/postgres-redis-sync:1.0.1` | Python sync daemon (psycopg2 + redis-py) |

To rebuild and push your own:

```bash
bash docker-build.sh
```

---

## Relationship to the article

This prototype intentionally keeps the stack simple (Postgres + Redis) to keep the
focus on the **orchestration pattern**, not the stack itself. The same structure —
`ClusterWorkflowTemplates` for components, a DAG workflow as the recipe, layered
lifecycle phases, and an end-to-end smoke test — applies to any stack: Kafka +
Schema Registry, Prometheus + Loki + Grafana, Vault + Consul, and so on.

The point is not what gets installed. The point is that **none of the existing
GitOps or packaging tools can express this sequence** as a first-class primitive.
Argo Workflows (and recipe built upon it) can.

---
