# Directory Structure and File Purposes

## Root (`/home/metanet/ProgramFiles/cdf-demo-kubernetes/`)
- **`README.md`**: Main guide. Quickstarts for kind/Minikube, repo layout, and notes about image substitution for local runs.
- **`Makefile`**: Local dev targets for kind. Builds Docker image, loads it into kind, deploys K8s Job with image placeholder replacement, shows logs, cleanup.
- **`Makefile.minikube`**: Same as `Makefile` but tailored for Minikube (start/stop cluster and image loading).
- **`BARE_BONES_DEMO.md`**: Hand-off notes: what’s included, quickstart, and a mapping to production concepts.
- **`quick-test.md`**: Notes on included enhancements (slides, Minikube makefile, optional data tests) and a quick test flow.
- **`requirements-dev.txt`**: Dev/test dependencies (pytest, pandas, pandera, great_expectations) for optional data validation tests.
- **`slides.md`**: Marp-compatible workshop slides (source).
- **`slides.pdf`**: Exported PDF of slides.
- **`LICENSE`**: Apache-2.0 license.
- **`docker/`**: Docker build context.
- **`k8s/`**: Kubernetes manifests (namespace, RBAC, Job).
- **`spark-app/`**: PySpark application and tests.
- **`docs/`**: Workshop documents and reference material.

## `docker/`
- **`docker/Dockerfile`**: Builds the Spark app image.
  - Base: `apache/spark-py:v3.5.1`
  - Copies `spark-app/` to `/opt/app/`
  - Comments indicate how to install extra Python deps via `spark-app/requirements.txt`.

## `k8s/`
- **`k8s/namespace.yaml`**: Creates `spark` namespace.
- **`k8s/rbac.yaml`**: ServiceAccount `spark-runner`, `Role` and `RoleBinding` to manage pods/jobs/logs/configmaps/secrets in `spark` namespace.
- **`k8s/job-spark.yaml`**: Kubernetes Job that runs `spark-submit` in cluster mode.
  - Uses image placeholder `{{IMAGE}}` (replaced by `make`).
  - Submits `local:///opt/app/app.py` with executor configs and resource requests/limits.

## `spark-app/`
- **`spark-app/app.py`**: PySpark job estimating Pi via Monte Carlo.
  - Builds `SparkSession`, parallelizes trials, computes Pi, prints result, stops Spark.
- **`spark-app/requirements.txt`**: Runtime app extra deps (currently `pandas>=2.0`; not auto-installed unless Dockerfile lines are uncommented).
- **`spark-app/tests/__init__.py`**: Empty, marks test package.
- **`spark-app/tests/test_pandera_contract.py`**: Pandera schema test validating a simple DataFrame contract.
- **`spark-app/tests/test_great_expectations.py`**: Great Expectations test; auto-skips if GE isn’t installed.

## `docs/`
- **`docs/cdf-workshop-apache-kubernetes.md`**, **`docs/workshop-1.md`**, and related `.md` files: Workshop content and guidance.
- **`docs/Apache Spark on Kubernetes Workshop.docx`**: Slide/workshop document.
- **`docs/spark-cd-workshop-starter/`**: Starter materials folder (subcontent for the workshop).

# How the Pieces Fit
- Build image from `docker/Dockerfile`, which packages `spark-app/app.py`.
- Deploy using `Makefile`/`Makefile.minikube`: creates namespace/RBAC, loads image into local cluster, replaces `{{IMAGE}}` in `k8s/job-spark.yaml`, applies the Job.
- Optional data tests run locally via `pytest` using `requirements-dev.txt`.

# Visual Directory Tree (ASCII)

```
cdf-demo-kubernetes/
├─ BARE_BONES_DEMO.md
├─ LICENSE
├─ Makefile
├─ Makefile.minikube
├─ README.md
├─ quick-test.md
├─ requirements-dev.txt
├─ slides.md
├─ slides.pdf
├─ docker/
│  └─ Dockerfile
├─ docs/
│  ├─ Apache Spark on Kubernetes Workshop.docx
│  ├─ cdf-workshop-apache-kubernetes.md
│  ├─ cdf_workshop_slide_deck_template_repo_readme_dev_ops_for_data_spark_on_containers (local only).md
│  ├─ cdf_workshop_slide_deck_template_repo_readme_dev_ops_for_data_spark_on_containers.md
│  ├─ workshop-1.md
│  └─ spark-cd-workshop-starter/
├─ k8s/
│  ├─ job-spark.yaml
│  ├─ namespace.yaml
│  └─ rbac.yaml
└─ spark-app/
   ├─ app.py
   ├─ requirements.txt
   └─ tests/
      ├─ __init__.py
      ├─ test_great_expectations.py
      └─ test_pandera_contract.py
```

# Annotated Kubernetes Manifests

Below are inline comments explaining each field. You can copy these into separate `*.annotated.yaml` files if you want to keep the originals clean.

## [k8s/namespace.yaml](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/k8s/namespace.yaml:0:0-0:0)
```yaml
apiVersion: v1            # Core API group for basic Kubernetes objects
kind: Namespace           # Declares a Namespace object
metadata:
  name: spark             # Namespace name that other manifests reference
```

## [k8s/rbac.yaml](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/k8s/rbac.yaml:0:0-0:0)
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

## [k8s/job-spark.yaml](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/k8s/job-spark.yaml:0:0-0:0)
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

# Annotated Dockerfile

## [docker/Dockerfile](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/docker/Dockerfile:0:0-0:0)
```dockerfile
FROM apache/spark-py:v3.5.1       # Official Spark image with Python support
WORKDIR /opt/app                  # App workdir used by spark-submit path
COPY spark-app/ /opt/app/         # Bundle PySpark app and optional deps into image
# COPY spark-app/requirements.txt ./   # Uncomment to add extra Python deps
# RUN pip install --no-cache-dir -r requirements.txt
```

