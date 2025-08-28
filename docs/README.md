# DevOps for Data — Spark on Containers (LOCAL-ONLY Starter)

Minimal, **100% local** demo: package a PySpark job into a Docker image and run it on a local Kubernetes cluster (**kind** or **Minikube**). No paid services, no registry pushes required.

## Prerequisites
- Docker
- `kubectl`
- One of: **kind** (recommended) or **Minikube**
- `make`

## Quickstart (kind)
```bash
make kind-up
make build
make load          # preload image into kind
make deploy-local  # apply Job using the local image
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

## Repository Layout
```
spark-cd-workshop-starter/
├─ spark-app/
│  └─ app.py                 # Example PySpark job
├─ docker/
│  └─ Dockerfile             # Build Spark app image
├─ k8s/
│  ├─ namespace.yaml         # Namespace "spark"
│  ├─ rbac.yaml              # ServiceAccount + Role/RoleBinding
│  └─ job-spark.yaml         # K8s Job: driver pod runs spark-submit
├─ Makefile                  # Local-only targets
├─ BARE_BONES_DEMO.md        # Hand-off notes and details
└─ LICENSE                   # Apache-2.0
```

## Notes
- The Dockerfile uses `apache/spark-py:v3.5.1` as base.
- Executors reuse the same image via `spark.kubernetes.container.image={{IMAGE}}`.
- `make deploy-local` replaces `{{IMAGE}}` in the manifest with the locally built tag and applies it.

## Clean up
```bash
kubectl delete job spark-pi -n spark --ignore-not-found
make kind-down
```
