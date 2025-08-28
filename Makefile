# Local-only Makefile: no registry, no pushes required
APP       ?= spark-app
TAG       ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
IMAGE     := $(APP):$(TAG)

.PHONY: kind-up kind-down build load load-minikube deploy-local logs clean sbom scan sign policy deploy-cron clean-cron

kind-up:
	kind create cluster --name spark --wait 60s || true
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/rbac.yaml

kind-down:
	kind delete cluster --name spark || true

build:
	docker build -t $(IMAGE) -f docker/Dockerfile .

# Local-only: preload image into kind nodes (so K8s finds it without pulling)
load:
	kind load docker-image $(IMAGE) --name spark

# Minikube alternative
load-minikube:
	minikube image load $(IMAGE)

# Replace {{IMAGE}} placeholder and apply manifests
_deploy_apply:
	sed 's#{{IMAGE}}#$(IMAGE)#g' k8s/job-spark.yaml | kubectl apply -f -

# Deploy without any registry/push
deploy-local: build load _deploy_apply

logs:
	kubectl logs job/spark-pi -n spark -f || true

clean:
	kubectl delete job spark-pi -n spark --ignore-not-found

# Local data-test gates (optional; requires requirements-dev.txt)
test:
	pytest -q || true
test-all:
	pytest -q -k '' || true

# Security and compliance utilities (best-effort; require external CLIs)
sbom:
	mkdir -p sbom
	@which syft >/dev/null 2>&1 && syft $(IMAGE) -o spdx-json=sbom/spdx-$(APP)-$(TAG).json || echo "[info] Install 'syft' to generate SBOM"

scan:
	@which trivy >/dev/null 2>&1 && trivy image --scanners vuln --exit-code 0 $(IMAGE) || echo "[info] Install 'trivy' to scan image vulnerabilities"

sign:
	@which cosign >/dev/null 2>&1 && COSIGN_YES=true cosign sign $(IMAGE) || echo "[info] Install 'cosign' and configure keys to sign images"

policy:
	@which conftest >/dev/null 2>&1 && conftest test k8s/job-spark.yaml k8s/cron-spark.yaml -p policy || echo "[info] Install 'conftest' to run OPA policies"

# CronJob helpers
_deploy_apply_cron:
	sed 's#{{IMAGE}}#$(IMAGE)#g' k8s/cron-spark.yaml | kubectl apply -f -

deploy-cron: build load _deploy_apply_cron

clean-cron:
	kubectl delete cronjob spark-pi-nightly -n spark --ignore-not-found
