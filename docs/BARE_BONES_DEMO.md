# BARE_BONES_DEMO.md (hand-off for Windsurf)

**Goal:** Minimal, self-contained demo of **CD for a Spark job on containers** using a local Kubernetes (kind or Minikube), a tiny Docker image, and a single Kubernetes **Job** manifest.

## What you get
- One PySpark job (`spark-app/app.py`)
- Docker image (`apache/spark-py` base)
- Kubernetes namespace/RBAC + **Job** manifest
- Make targets to build → deploy → watch

## Quickstart (kind)
```bash
make kind-up
make build
make load
make deploy-local
kubectl logs job/spark-pi -n spark -f
make kind-down
```

## Quickstart (Minikube)
```bash
minikube start --cpus=3 --memory=4096
make build
make load-minikube
make deploy-local
kubectl logs job/spark-pi -n spark -f
```

## Files to create (already included here)
- `Makefile` (local-only targets; no registry needed)
- `docker/Dockerfile` (base spark image)
- `spark-app/app.py` (Pi estimation example)
- `k8s/namespace.yaml`, `k8s/rbac.yaml`, `k8s/job-spark.yaml`

## Production mapping (later)
- Replace Job with **SparkApplication** (Spark Operator) or use **CronJob** for schedules.
- Add tests, SBOM/signing, and policy gates in CI before deployment.
- Add Prometheus scrape annotations and central logging.
