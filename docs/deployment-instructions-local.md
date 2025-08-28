# Deployment instructions (LOCAL)

For starters you may face this issue 

- __kind not installed__: `/bin/sh: 1: kind: not found`
- __kubectl pointing to DigitalOcean__: Your current kubeconfig context is a DigitalOcean cluster, so `kubectl apply` tries to talk to DO via `doctl` and fails auth. For local demo, switch kubectl to a local cluster.


Run these commands in your terminal.

1) Install kind (Linux)
```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
kind version
```

2) Ensure kubectl uses no cloud context
```bash
# Optional: if KUBECONFIG is set, clear it so kubectl uses default ~/.kube/config
echo "${KUBECONFIG:-unset}"
unset KUBECONFIG  # only if it was set
kubectl config get-contexts || true
```

3) Create the local cluster and set context
```bash
make kind-up
# After creation, kubectl context should be "kind-spark"
kubectl config use-context kind-spark
kubectl cluster-info
kubectl get nodes
```

4) Build, load, and deploy the Spark Job
```bash
make deploy-local
```
This builds the image from [docker/Dockerfile](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/docker/Dockerfile:0:0-0:0), loads it into kind, and applies [k8s/job-spark.yaml](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/k8s/job-spark.yaml:0:0-0:0) with the image substituted.

5) Stream logs and verify output
```bash
make logs
```
Expected: a line like `Pi is roughly 3.14...`

6) Inspect resources (optional)
```bash
kubectl get pods -n spark
kubectl describe job spark-pi -n spark
```

7) Cleanup (optional)
```bash
make clean
make kind-down
```

## Why we used kind and Makefiles

- __Local, offline-friendly Kubernetes (no cloud required)__  
  - `kind` runs K8s in Docker on your machine. No DigitalOcean/EKS/GKE/AKS needed.  
  - Matches your constraint: locally deployable, open‑source, no paid services.

- __Reproducible dev environment for a workshop__  
  - One command spins up a clean cluster every time: `make kind-up`.  
  - No drift: [k8s/namespace.yaml](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/k8s/namespace.yaml:0:0-0:0), [k8s/rbac.yaml](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/k8s/rbac.yaml:0:0-0:0), [k8s/job-spark.yaml](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/k8s/job-spark.yaml:0:0-0:0) define everything as code.

- __Fast inner loop for containerized Spark__  
  - `make deploy-local` builds [docker/Dockerfile](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/docker/Dockerfile:0:0-0:0) → image `spark-app:<tag>`, loads it into kind (no registry), applies the Job with the image injected.  
  - `make logs` tails the job output so the audience sees “Pi is roughly …” immediately.  
  - `make clean` resets state; `make kind-down` tears down the cluster.

- __Simple, teachable CD pattern__  
  - The Makefile is your “pipeline script,” mapping clean targets to steps:
    - `build` (containerize app from [spark-app/app.py](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/spark-app/app.py:0:0-0:0))  
    - `load` (preload image to the cluster to avoid pulls)  
    - `deploy-local` (template [k8s/job-spark.yaml](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/k8s/job-spark.yaml:0:0-0:0) with `{{IMAGE}}`)  
    - `logs`, `clean`, `deploy-cron` (CronJob demo)
  - This mirrors production CD while staying local: replace `kind load` with push to a registry; apply same manifests to a real cluster.

- __Consistency and clarity for attendees__  
  - Fewer moving parts to explain on stage.  
  - All commands are standardized and discoverable in [Makefile](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/Makefile:0:0-0:0), and documented in [docs/deployment-instructions-local.md](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/docs/deployment-instructions-local.md:0:0-0:0).

- __Good security/RBAC hygiene, even locally__  
  - [k8s/rbac.yaml](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/k8s/rbac.yaml:0:0-0:0) grants least‑privilege (with needed `deletecollection`) to SA `spark-runner`.  
  - [k8s/job-spark.yaml](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/k8s/job-spark.yaml:0:0-0:0) binds the driver to that SA via `serviceAccountName` and Spark conf.

## How this maps to production

- Replace `kind` with your managed cluster/context.  
- Push images to a registry instead of `kind load`.  
- Keep manifests the same or use the Spark Operator CRDs.  
- Wrap with your CI/CD (Tekton/Jenkins/GitHub Actions) for automated builds/tests/signing.

## Files that make this work

- [Makefile](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/Makefile:0:0-0:0) targets: `kind-up`, `deploy-local`, `logs`, `clean`, `deploy-cron`.  
- Docker: [docker/Dockerfile](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/docker/Dockerfile:0:0-0:0) (`FROM spark:3.5.1-python3`).  
- K8s: [k8s/namespace.yaml](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/k8s/namespace.yaml:0:0-0:0), [k8s/rbac.yaml](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/k8s/rbac.yaml:0:0-0:0), [k8s/job-spark.yaml](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/k8s/job-spark.yaml:0:0-0:0).  
- App: [spark-app/app.py](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/spark-app/app.py:0:0-0:0).

## Status

- Your demo now runs end‑to‑end locally with kind and Make targets.  
- You can reliably show the result and reset quickly between runs.

## Quick troubleshooting

- __Still seeing DigitalOcean in use?__
  - Check and switch context:
    ```bash
    kubectl config get-contexts
    kubectl config use-context kind-spark   # or minikube
    ```
- __ImagePullBackOff with Minikube?__
  - Ensure you ran `make load-minikube` and used matching `${IMAGE}` in the sed/apply step.
- __RBAC errors__:
  - Confirm `spark-runner` SA and rolebinding exist:
    ```bash
    kubectl get sa -n spark
    kubectl get role,rolebinding -n spark
    ```

If you run the kind steps above now, you should be able to demo the local job end-to-end and show the “Pi is roughly …” output referenced in:
- `docs/Apache Spark on Kubernetes Workshop.docx`
- `docs/cdf_workshop_slide_deck_template_repo_readme_dev_ops_for_data_spark_on_containers (local only).md`

If build still fails
- __Network rate limit on Docker Hub: retry in ~1–2 minutes.__
- __Verify Docker is running and you have disk space.__
- __Confirm context is local:__
```bash
kubectl config current-context  # should be kind-spark
```
Once the Dockerfile is saved with FROM spark:3.5.1-python3, re-run make deploy-local then make logs. You should be good for the workshop demo.


## Check success

Show success quickly:
```bash
kubectl get pods -n spark
kubectl logs -n spark -l spark-role=driver --tail=-1 | grep -i 'Pi is roughly'
```

Re-run the demo end-to-end:

```bash
make clean
make deploy-local
make logs
```

Optional cleanup after demo:
```bash
make clean
make kind-down
```




# Alternative: Minikube path

If you prefer Minikube:

1) Start Minikube and confirm context
```bash
minikube start --cpus 3 --memory 4096
kubectl config use-context minikube
kubectl get nodes
```

2) Apply namespace/RBAC, build and load the image, deploy the Job
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/rbac.yaml

make build
make load-minikube

export TAG=$(git rev-parse --short HEAD 2>/dev/null || echo dev)
export IMAGE=spark-app:${TAG}
sed "s#{{IMAGE}}#${IMAGE}#g" k8s/job-spark.yaml | kubectl apply -f -
```

3) Watch logs
```bash
kubectl logs job/spark-pi -n spark -f
```

4) Cleanup
```bash
kubectl delete job spark-pi -n spark --ignore-not-found
kubectl delete namespace spark
minikube stop
```
```bash
make clean
# and when completely done
make kind-down
```
