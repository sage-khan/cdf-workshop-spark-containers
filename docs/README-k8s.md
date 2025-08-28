# Kubernetes Manifests and Dockerfile — Annotated Reference

This document explains each field in the Kubernetes manifests under `k8s/` and highlights key lines in the `docker/Dockerfile`. Keep using the original files for deployment; this is a read-only reference.

---

## k8s/namespace.yaml (annotated)
```yaml
apiVersion: v1            # Core API group for basic Kubernetes objects
kind: Namespace           # Declares a Namespace object
metadata:
  name: spark             # Namespace name that other manifests reference
```

---

## k8s/rbac.yaml (annotated)
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: spark-runner      # SA used by the Spark driver pod
  namespace: spark        # Lives in the same namespace as the Job
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: spark-edit        # Namespaced Role with edit-like permissions
  namespace: spark
rules:
- apiGroups: ["", "batch", "apps"]         # "" = core API (pods, services, etc)
  resources: ["pods", "pods/log", "services", "configmaps", "secrets", "jobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  # Grants the driver enough permissions to create/read pods (executors), access logs,
  # reference secrets/configmaps, and manage its Job lifecycle within the namespace.
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: spark-edit
  namespace: spark
subjects:
- kind: ServiceAccount
  name: spark-runner      # Binds the Role to our driver SA
  namespace: spark
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: spark-edit
```

---

## k8s/job-spark.yaml (annotated)
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: spark-pi                      # Job name; used for logs and cleanup
  namespace: spark                    # Targets the 'spark' namespace created earlier
spec:
  backoffLimit: 0                     # Do not retry on failure (fail fast for demos)
  ttlSecondsAfterFinished: 600        # Auto-cleanup completed Job after 10 minutes
  template:
    spec:
      restartPolicy: Never            # Pods won't auto-restart
      serviceAccountName: spark-runner  # Use SA with RBAC permissions defined above
      containers:
      - name: driver
        image: {{IMAGE}}              # Placeholder replaced by `make` with built tag
        imagePullPolicy: IfNotPresent # Use local image if already loaded (kind/minikube)
        command: ["/opt/spark/bin/spark-submit"]  # Entrypoint: spark-submit
        args:
          [
            "--master", "k8s://https://kubernetes.default.svc", # Submit to in-cluster API
            "--deploy-mode", "cluster",       # Driver runs in cluster (not client mode)
            "--conf", "spark.kubernetes.container.image={{IMAGE}}", # Executors use same image
            "--conf", "spark.kubernetes.namespace=spark",  # Namespace for driver/executors
            "--conf", "spark.executor.instances=2",        # Number of executors
            "--conf", "spark.executor.memory=1g",          # Executor memory
            "--conf", "spark.executor.cores=1",            # CPU cores per executor
            "local:///opt/app/app.py"      # PySpark app inside image (local:// = image FS)
          ]
        resources:
          requests: { cpu: "500m", memory: "512Mi" }  # Minimum guaranteed resources
          limits:   { cpu: "1",    memory: "1Gi" }    # Upper bounds (throttling/eviction)
```

---

## docker/Dockerfile (annotated)
```dockerfile
FROM apache/spark-py:v3.5.1       # Official Spark image with Python support
WORKDIR /opt/app                  # App workdir used by spark-submit path
COPY spark-app/ /opt/app/         # Bundle PySpark app and optional deps into image
# COPY spark-app/requirements.txt ./   # Uncomment to add extra Python deps
# RUN pip install --no-cache-dir -r requirements.txt
```

---

## How this ties together
- Build with `make build` (or Minikube makefile). The image includes `spark-app/app.py`.
- Load image locally with `make load` (kind) or `make load-minikube` (Minikube).
- Deploy with `make deploy-local` which replaces `{{IMAGE}}` in `k8s/job-spark.yaml` and applies manifests.
- View logs: `make logs`.

If you prefer separate `*.annotated.yaml` files alongside the originals, let me know and I can add them too.
