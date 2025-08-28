# Detailed Commanmds

## Create conda environment
```bash 
conda create -n cdf-demo python==3.11
conda activate cdf-demo
```

## Install kind
```bash
make kind-up
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
kind version
```

## Unset KUBECONFIG
```bash
echo "${KUBECONFIG:-unset}"
unset KUBECONFIG
kubectl config get-contexts || true
```

## Start kind cluster
```bash
make kind-up
kubectl cluster-info
kubectl get nodes
kubectl cluster-info
kubectl get nodes
```

## Deploy local
```bash
make deploy-local
#Builds image from docker/Dockerfile
#Loads it into kind.
#Applies k8s/job-spark.yaml with the image injected.

make logs #Expect “Pi is roughly …”.
```
## Quick Checks
```bash 
#Quick Checks
kubectl get pod -n spark -l job-name=spark-pi -o jsonpath='{.items[0].spec.serviceAccountName}'; echo
kubectl get pods -n spark
kubectl describe pod -n spark -l job-name=spark-pi
kubectl logs -n spark -l spark-role=driver --tail=200
# kubectl apply -f k8s/rbac.yaml # to apply new changes to any yaml files
```
## Rerun from scratch
```bash
make clean
make deploy-local
make logs
# OR clear && make clean && make deploy-local && make logs

# Check status
kubectl get pods -n spark
kubectl logs -n spark -l spark-role=driver --tail=-1 | tee /tmp/spark-driver.log
grep -i 'Pi is roughly' /tmp/spark-driver.log || true
```



# Quicktest

* **Slides**: `slides.md` (Marp-compatible) and a `slides.pdf` export included in the zip.
* **Minikube-only**: extra `Makefile.minikube` with `minikube-up/minikube-down/load-minikube/deploy-local` targets (the original Makefile still supports kind).
* **Optional data tests**: `requirements-dev.txt` plus `spark-app/tests/test_pandera_contract.py` and `spark-app/tests/test_great_expectations.py` (GE test auto-skips if GE isn’t installed).

Grab it here:

[Download the updated starter repo (spark-cd-workshop-starter.zip)](sandbox:/mnt/data/spark-cd-workshop-starter.zip)

Quick local test:

```bash
# kind path
make kind-up
python3 -m pip install -r requirements-dev.txt
make test           # optional data gates (pandera + GE if installed)
make build && make load && make deploy-local
kubectl logs job/spark-pi -n spark -f
make kind-down

# or Minikube path
make -f Makefile.minikube minikube-up
python3 -m pip install -r requirements-dev.txt
make -f Makefile.minikube deploy-local
kubectl logs job/spark-pi -n spark -f
make -f Makefile.minikube minikube-down
```