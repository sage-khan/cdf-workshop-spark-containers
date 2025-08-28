---
marp: true
paginate: true
headingDivider: 2
---

# DevOps for Data: Delivering & Orchestrating Apache Spark on Containers
**CD Foundation / Linux Foundation Workshops**  
Speaker: Muhammad Danyal "Sage" Khan  
Date: August 28

---

## Why DevOps/CD for Spark (not “just Kubernetes”)
- Spark powers business‑critical data products, yet many jobs bypass CI/CD guardrails.
- We need immutable artifacts, promotion, rollbacks, and SLOs—just like app teams.
- Containers → reproducible runtime. CD → trusted, auditable delivery. CDEvents → end‑to‑end traceability.

---

## CD Blueprint for Spark (at a glance)
Flow: commit → CI build (image/jar) → tests (code+data+deps) → SBOM & sign → CD apply → observe & rollback

```
Git push -> CI (build & test) -> Registry (image + SBOM + signature)
                         | CDEvents: artifact.published
                         v
                    CD Pipeline (promote/apply)
                         v
Kubernetes: Spark Job / CronJob / SparkApplication (Driver + Executors)
```

---

## Packaging & Quality Gates (Code + Data + Supply Chain)
- One job = one image (or jar/wheel) with pinned Spark & libs.
- Code tests (pytest/ScalaTest); Data tests (pandera/GE).
- Security: Trivy, SBOM (Syft), signatures (Cosign), attestations.
- Policy-as-code gates.

---

## Orchestration Targets
- Kubernetes (demo): Job/CronJob, Spark Operator CRD.
- Others: OpenShift, Nomad, managed Spark—same CD pattern.

---

## Live Demo (8 min)
1. kind-up → local cluster  
2. build && test → image + checks  
3. sbom && sign → provenance  
4. deploy → run job; logs  
5. cron-deploy (optional)

---

## Observability & SLOs
- Metrics: Prometheus/Grafana (job latency, stage time, shuffle IO, executor CPU/mem)
- Logs: ELK/Cloud with correlation IDs
- SLOs: job latency, success %, cost/run

---

## Platform Guardrails
- Namespaces, ResourceQuota, LimitRange, admission policies
- Secrets: Vault/ESO; least privilege
- Cost: requests/limits, VPA, autoscaler, TTL
- Release mgmt: immutable images; rollbacks

---

## Risks & Fixes
- Pods Pending: node reserve & pod overhead; right-size; autoscale
- OOMKilled: raise memoryOverhead; <=5 cores/executor
- Cold starts: pre-pull; slim base layers
- Config drift: GitOps overlays
- Data regressions: block deploy on data tests

---

## Production Mapping & CTA
Local: kind + Job + embedded spark-submit  
Prod: EKS/GKE/AKS + Spark Operator/Argo Workflows; GitOps; Vault; autoscaling; SSO/RBAC; cost dashboards


