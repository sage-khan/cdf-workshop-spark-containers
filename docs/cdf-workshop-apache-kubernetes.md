# DevOps for Data: Delivering & Orchestrating Apache Spark on Containers

**Duration:** 30 minutes (talk + live demo)
**Mode:** Presenter-led (YouTube), self-contained/open-source stack

## 0) Prep (before you go live)

* **Laptop:** 8+ vCPU / 16+ GiB RAM
* **Tools:** Docker, `kubectl`, **kind** (or Minikube), `make`, Python 3.11, Java 11+, (optional) `cosign`, `syft`, `trivy`
* **Clone template repo (structure below)** and pre-pull images to avoid delays

```
repo/
 ├─ spark-app/                # PySpark example + tests
 │   ├─ app.py                # job logic
 │   ├─ tests/                # unit + data checks
 │   └─ requirements.txt
 ├─ docker/                   
 │   └─ Dockerfile            # FROM spark:3.5.1 base + app deps
 ├─ k8s/                      
 │   ├─ job-spark.yaml        # K8s Job driver + executors via Spark-on-K8s
 │   └─ cronjob-spark.yaml    # Nightly promotion example
 ├─ ci/                       
 │   ├─ tekton/               # Optional: Tekton Pipeline & Tasks
 │   └─ github-actions/       # Alt CI sample (build, test, sbom, sign)
 └─ Makefile                  # one-liners: kind-up, build, test, deploy
```

---

## 1) Agenda & Timeboxes (30:00)

**00:00–03:00 | Why DevOps/CD for Spark (not “just K8s”)**

* Spark jobs = business-critical releases → need **artifact immutability, audit, promotion, rollback, SLOs**
* Containers give reproducibility; **CD** gives trust & speed; **CDEvents** gives traceability

**03:00–08:00 | Architecture & CD Blueprint**

* **Flow:** *commit → CI build (image/jar) → tests (code+data+deps) → sign/SBOM → CD apply (Job/CronJob/SparkApplication) → observe/rollback*
* **CDF fit:** Tekton/Jenkins pipelines; **CDEvents** for triggers; **Ortelius-style** inventory/SBOM concepts for provenance
* **Roles @ big co:** Platform (guardrails), Dev/Data Eng (apps), Sec (supply chain), SRE (SLOs)

**08:00–12:00 | Packaging & Quality Gates (Code + Data)**

* **Package:** one-image-per-job; pin Spark & Python libs; layer caching
* **Tests:**

  * Unit/integration (PyTest/ScalaTest)
  * **Data contracts** (schemas, row counts, freshness, null rules) with Great Expectations or pandera
  * **Dependency/security** (pip/audit + Trivy), **SBOM** (Syft), **sign** (Cosign)
* **Policy-as-code gates:** block promotion if tests/scans fail

**12:00–14:00 | Orchestration Options (map to “containers”, not K8s-only)**

* **Kubernetes (concrete demo):** Spark driver/executors as pods; Job/CronJob; Spark Operator (optional)
* **Other runtimes (conceptual):** OpenShift, Nomad, serverless spark; same CD pattern, different apply step

**14:00–22:00 | Live Demo (fast path, all OSS, local)**
*Goal:* Show the end-to-end CD loop in **8 minutes** with one-liners.

* **Step A — Cluster:** `make kind-up` → creates kind + metrics server
* **Step B — CI sim:**

  * `make build` → Docker build (Spark base + app)
  * `make test` → run unit + data tests locally
  * `make sbom` → generate SBOM; `make sign` → optional cosign sign
* **Step C — CD apply:**

  * `make deploy` → `kubectl apply -f k8s/job-spark.yaml`
  * `kubectl get pods -w` → show driver/executors
  * `kubectl logs job/spark-pi -f` → success output + metrics hints
* **(Optional)** `make cron-deploy` → show CronJob for promotion to nightly

**22:00–26:00 | Production Checklist for Big Software Companies**

* **Multi-tenancy & quotas:** Namespaces, `ResourceQuota`, `LimitRange`, admission policies
* **Secrets & compliance:** External Secrets Operator / Vault; image policies; **attestation** (SLSA/in-toto patterns)
* **Cost controls:** Requests/limits, vertical pod autoscaler for drivers, cluster autoscaler, **TTL** for finished jobs, spot/priority
* **Observability:** Spark metrics → Prometheus/Grafana; logs to ELK/Cloud; SLOs: job latency, success rate, cost/job
* **Release mgmt:** *environments* (dev/stage/prod), **immutable images**, **rollbacks** via previous tag; change tickets auto-generated from CDEvents

**26:00–29:00 | Risk & Pitfalls (and fixes)**

* **Pods Pending / resource mismatch:** right-size executor mem/cores; account for K8s **node reserves** & **pod overhead**
* **OOMKilled (Python/large shuffle):** raise `spark.executor.memoryOverhead` (e.g., 25–40%); fewer cores/executor (≤5)
* **Long cold-starts:** pre-pull images; node image cache; smaller base layers
* **Config drift:** repo-owned manifests/Helm; GitOps; environment overlays
* **Data quality regressions:** block deploy on **data-test** failures; expose data SLOs

**29:00–30:00 | Close & CTA**

* Link to template repo, copy-paste commands, and “production mapping” doc
* Invite to CDF Slack/DataOps WG; ask for 2 use-cases to pilot

---

## Demo Commands (copy block)

```bash
# 1) Spin up local cluster
make kind-up
# 2) Build, test, generate SBOM, (optionally) sign
make build && make test && make sbom && make sign
# 3) Deploy Spark job to the cluster
make deploy
kubectl get pods -w
kubectl logs job/spark-pi -f
# 4) (Optional) Schedule nightly run
make cron-deploy
```

**Key manifests (excerpt):**

```yaml
# k8s/job-spark.yaml  — minimal CD target (no operator)
apiVersion: batch/v1
kind: Job
metadata:
  name: spark-pi
spec:
  template:
    spec:
      restartPolicy: Never
      serviceAccountName: spark-runner
      containers:
      - name: driver
        image: ghcr.io/acme/spark-app:{{GIT_SHA}}
        args: ["bin/spark-submit",
               "--master", "k8s://https://kubernetes.default.svc",
               "--deploy-mode", "cluster",
               "--conf", "spark.kubernetes.container.image=ghcr.io/acme/spark-app:{{GIT_SHA}}",
               "--conf", "spark.executor.instances=2",
               "--conf", "spark.executor.memory=2g",
               "--conf", "spark.executor.cores=1",
               "local:///opt/app/app.py"]
        resources:
          requests: { cpu: "500m", memory: "512Mi" }
          limits:   { cpu: "1",    memory: "1Gi" }
```

*(Swap to a `SparkApplication` CR if you prefer the Spark Operator; same CD idea, different object.)*

---

## “Big Co” Concepts to Emphasize (tie to DataOps & CDF)

* **Release as a Data Product:** Spark job = versioned, signed, SBOM’d artifact with **data contracts** as gates
* **Environment Promotion:** dev→stage→prod with **CDEvents** trace (who/what/when/why)
* **Guardrails by Platform:** Namespaces, quotas, policy-as-code; **golden image** per runtime; central secrets and KMS
* **Reliability & SLOs:** job latency, success %, cost/run; error budgets drive prioritization
* **Compliance:** provenance (attestations), retention, PII handling; evidence exported from the pipeline

---

## Slide Outline (10 slides max)

1. Problem & Motivation (DevOps for Data)
2. CD Blueprint for Spark (big diagram)
3. Packaging & Quality Gates (code + data + supply chain)
4. Orchestration Targets (K8s concrete, others conceptually)
5. Live Demo Steps (commit→deploy)
6. Observability & SLOs
7. Platform Guardrails (multi-tenancy, secrets, cost)
8. Risk & Pitfalls (with fixes)
9. Production Mapping (managed K8s, GitOps, Operator)
10. CTA + Links

---

## Handout: 1-Pager “Production Mapping”

* **Local (workshop):** kind + K8s Job + spark-submit inside driver container
* **Prod:** EKS/GKE/AKS + Spark Operator (SparkApplication) or Argo Workflows; GitOps (Argo CD/Flux); external registry; Vault/ESO; autoscaling; org SSO/RBAC; cost dashboards

---

If you want, I can turn this into a **slide deck** + **template repo README** in your voice (with Makefile and manifests wired up).


Awesome — here are the three items you asked for.

# 50-word promo blurb

Bring DevOps discipline to data. This hands-on workshop shows how to package, test, and continuously deliver Apache Spark to container-orchestrated platforms. We’ll build a versioned Spark image, run automated code/data checks, and promote jobs with CDEvents-driven pipelines (Tekton/Jenkins) to Kubernetes—complete with observability, rollbacks, and guardrails that are secure and reliable.

# Five key takeaways

* **CD blueprint for Spark:** From commit → artifact (image/jar/wheel) → automated checks → environment promotion → safe rollouts (Jobs/CronJobs/SparkApplication) with rollback strategies.
* **Quality gates for code *and* data:** Unit + integration tests, schema/contract checks, lightweight data validations; include dependency scanning, SBOM, and signatures.
* **CDEvents for orchestration:** Event-driven pipelines and notifications across CI, registry, and runtime; traceability from build to execution.
* **Platform guardrails:** Namespaces & quotas, secrets management, cost controls, multi-tenancy patterns, and operational SLOs for batch jobs.
* **From laptop to prod:** Reproducible local demo (kind/Minikube) mapped to managed K8s (EKS/GKE/AKS) with Tekton/Jenkins pipeline templates you can reuse.

# One-slide visual (drop-in diagram)

```
                   ┌────────────────────────────────────────────────────┐
                   │                     Source Control                 │
                   │                 Git (PRs / Tags / MR)              │
                   └───────────────┬────────────────────────────────────┘
                                   │  CDEvents:  code.pushed / pr.merged
                          ┌────────▼────────┐
                          │       CI        │   (Tekton or Jenkins)
                          │  Build & Test   │
                          └───────┬─────────┘
    code tests  ────────────────▶│          │◀──────────── data tests
 dependency scan ───────────────▶│          │ (unit/integration/schema)
      SBOM+sign  ───────────────▶│          │
                          ┌───────▼─────────┐
                          │  Artifact Store │   (OCI Registry)
                          │  Image + SBOM   │
                          └───────┬─────────┘
                                   │  CDEvents: artifact.published
                          ┌────────▼────────┐
                          │       CD        │   (Tekton/Jenkins pipeline)
                          │  Promote/Deploy │
                          └───────┬─────────┘
                      rollout started/finished events
                                   │
                   ┌───────────────▼────────────────┐
                   │        Runtime (Kubernetes)     │
                   │  SparkApplication / Job / CRON  │
                   │  Driver Pod  ←→  Executor Pods  │
                   └───────────────┬────────────────┘
                                   │  logs/metrics/traces events
                     ┌─────────────▼──────────────┐
                     │   Observability & ChatOps  │
                     │  (Prom/Grafana + Alerts)   │
                     └────────────────────────────┘
```

**Speaker notes for the slide (optional, 2–3 bullets):**

* *Flow:* Commit → CI builds signed Spark artifact → CDEvents triggers CD → CD applies K8s manifest (Job/CronJob/SparkApplication) → Observe and roll back if needed.
* *Controls:* Quality gates (code + data), provenance (SBOM/signing), and environment promotion rules.
* *Portability:* Same pattern runs locally (kind/Minikube) and scales on managed K8s.

If you want, I can package this as a single slide image or a one-page PDF for the CDF announcement.

Below are **reference-grade sizing cheat-sheets** you can drop straight into your workshop deck or notes.
They show *rough-order-of-magnitude* numbers that work well for most teams and point out where Kubernetes adds (or hides!) extra cost.  Treat the figures as starting baselines—always profile and tune for your actual workload.

---

### 1  Baseline cluster sizing — monolithic vs. Kubernetes

| Work-load tier (≈ data processed / day) | Monolithic Spark (stand-alone or YARN)                                                                                                  | Spark on Kubernetes\*                                                                                                                                          | Why the difference?                                                                                                                                               |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Small / Dev (< 100 GB)**              | • 1 node (laptop/VM) **4 vCPU / 8 GiB** runs local\[4]<br>• For a *“real”* mini-cluster: **3 × (4 vCPU / 16 GiB)** workers              | • `minikube` or `kind` single-node cluster: **3 vCPU + 4 GiB** minimum to launch driver + 1 executor ([Apache Spark][1])                                       | K8s needs a little extra for control-plane pods plus **pod overhead** (≈ 250 mCPU + 120 Mi) per Spark pod when RuntimeClass overhead is enabled ([Kubernetes][2]) |
| **Medium (0.1 – 1 TB)**                 | **10 × (16 vCPU / 64 GiB)** workers<br>Driver 4 core / 8 GiB<br>Executors `--num-executors 20 --executor-cores 4 --executor-memory 16g` | Same 10 nodes, *but* K8s reserves \~**6–25 %** of RAM & 6 % of the 1st core, then 1 % of cores > 1 for system daemons (GKE/EKS rule-of-thumb) ([LearnKube][3]) | Pods declare **requests & limits**; scheduler must fit *requests + overhead* onto allocatable node resources.                                                     |
| **Large (1 – 10 TB)**                   | **30 × (32 vCPU / 128 GiB)** workers<br>Driver 8 core / 16 GiB<br>Executors ≈ 100 pods, 4 core / 32 GiB each                            | Same raw HW; K8s reserve on big nodes drops to \~**4 %** memory and \~0.25 % CPU/core ([LearnKube][3])                                                         | Larger nodes amortise K8s overhead; cluster-autoscaler can add/remove nodes elastically.                                                                          |

\* Figures assume the Spark 4.0 official image and default JVM workloads; non-JVM executors (Python, GPU, etc.) need higher `memoryOverhead` (40 % default from Spark 3.3+) ([Apache Spark][4]).

---

### 2  “Golden” Spark submit knobs

| Parameter                                      | **Typical start-point**                                                     | K8s-specific note                                                                                      | Source                           |
| ---------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | -------------------------------- |
| `--executor-cores`                             | **3 – 5** cores per executor (keeps GC & context-switch overhead down)      | You can override with `spark.kubernetes.executor.request.cores` / `limit.cores` for fine-grained QoS.  | ([Medium][5])                    |
| `--executor-memory`                            | **8 – 16 g** (scale with data; stay ≤ 32 g to avoid huge-page GC penalties) | Same value; container limit = memory + overhead.                                                       | ([Medium][5], [Apache Spark][4]) |
| `spark.executor.memoryOverhead`                | `max(10 % of executor-mem, 384m)` (Spark default)                           | **Must** be sized or pods OOM-kill; non-JVM images default to 40 %.                                    | ([Apache Spark][4])              |
| `--num-executors` / `spark.executor.instances` | Small 2-4 • Med 20 • Large 100 (or enable dynamic allocation)               | Most users enable **Dynamic Allocation** + K8s Cluster-Autoscaler.                                     | ([Medium][5])                    |
| `--driver-memory`                              | Small 4 g • Med 8 g • Large 16 g                                            | Add `spark.kubernetes.authenticate.driver.serviceAccountName=<sa>` so driver can create executor pods. | ([Apache Spark][1])              |
| K8s pod overhead                               | n/a                                                                         | RuntimeClass-defined or default (\~120 Mi + 250 mCPU/pod, counted by scheduler)                        | ([Kubernetes][2])                |
| Node reserve (K8s only)                        | n/a                                                                         | GKE example: 25 % of first 4 GiB, 20 % next 4 GiB, etc.                                                | ([LearnKube][3])                 |

---

### 3  Common gotchas & cures

| Symptom                                                 | Where it shows up  | Root cause                                                             | Quick fix / prevention                                                                                                                            |
| ------------------------------------------------------- | ------------------ | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`MemoryOverhead Exceeded` → executor pod OOM-Killed** | Kubernetes         | default 10 % overhead too small for large shuffles or Python + JVM mix | bump `spark.executor.memoryOverhead` (e.g. 4096m) or set higher `memoryOverheadFactor`; monitor with `kubectl describe pod` ([Stack Overflow][6]) |
| **`ImagePullBackOff` / pod stuck `Pending`**            | Kubernetes         | wrong image tag, private registry auth, or local build not pushed      | verify `image:`, run `kubectl describe pod`, add imagePullSecrets, or use a local registry for dev ([Lumigo][7])                                  |
| Pod `Pending` – no node has resources                   | Kubernetes         | requests + overhead larger than allocatable (node reserve!)            | lower executor mem/cores, enable Cluster-Autoscaler, or pick bigger node type ◆                                                                   |
| Straggler tasks / long GC pauses                        | Both               | too many cores per executor or heap too large                          | keep executor ≤ 5 cores, ≤ 32 GiB; switch to G1GC (`spark.executor.extraJavaOptions=-XX:+UseG1GC`) ([Dev Genius][8])                              |
| GC-overhead / `java.lang.OutOfMemoryError`              | Both               | storage/execution memory not balanced                                  | raise executor memory, tune `spark.memory.fraction` or cache less data; prefer **AQE** for skew joins ([Stack Overflow][9])                       |
| Cluster under-utilised (monolithic)                     | Stand-alone / YARN | static partitioning & long cluster startup                             | enable **dynamic allocation** or migrate to Kubernetes shared pool                                                                                |
| Shuffle network bottleneck                              | Both (large jobs)  | disks slow or 1 GbE network                                            | use SSD temp space (`spark.local.dir` on NVMe), ensure 10 GbE+ NICs; on K8s, consider push-based shuffle service                                  |

---

### 4  Rules of thumb you can quote

* **Memory:** Aim for executors ≤ 32 GiB; JVMs > 200 GiB behave poorly. Keep driver smaller than the largest executor. ([Apache Spark][10])
* **CPU per node:** provision **8–16 cores min**; Spark scales almost linearly up to tens of cores. ([Apache Spark][10])
* **Disk:** 4-8 local SSDs per node, mounted separately, no RAID, `noatime` option. ([Apache Spark][10])
* **K8s overhead budgeting:** for managed services reserve **\~6 % CPU of first core + 0.25 % above 4 cores** and **\~5-25 % RAM on small nodes**; bigger nodes waste less. ([LearnKube][3])
* **Minikube demo:** start with `minikube start --cpus 3 --memory 4096` or Spark won’t fit even one executor. ([Apache Spark][1])

Use these tables as quick-reference slides, then dive into tuning demos during your video. They’ll help your data-engineering audience understand *how much* to ask for—and *why* Kubernetes’ numbers never line up one-for-one with their old YARN clusters.

[1]: https://spark.apache.org/docs/latest/running-on-kubernetes.html "Running Spark on Kubernetes - Spark 4.0.0 Documentation"
[2]: https://kubernetes.io/docs/concepts/scheduling-eviction/pod-overhead/ "Pod Overhead | Kubernetes"
[3]: https://learnkube.com/allocatable-resources "Allocatable memory and CPU in Kubernetes Nodes"
[4]: https://spark.apache.org/docs/latest/configuration.html "Configuration - Spark 4.0.0 Documentation"
[5]: https://medium.com/%40krthiak/apache-spark-is-powerful-but-like-any-high-performance-engine-it-needs-the-right-fuel-88ba4c5749f8 "Spark Resource Allocation Decoded: Best Practices Using spark-submit | by Karthik | Jun, 2025 | Medium"
[6]: https://stackoverflow.com/questions/77121410/solving-oom-issue-for-a-spark-job?utm_source=chatgpt.com "Solving OOM Issue for a spark Job - Stack Overflow"
[7]: https://lumigo.io/kubernetes-troubleshooting/kubernetes-imagepullbackoff/?utm_source=chatgpt.com "What Is Kubernetes ImagePullBackOff Error and How to Fix It"
[8]: https://blog.devgenius.io/from-out-of-memory-to-optimized-handling-java-heap-space-gc-overhead-limit-exceeded-issues-in-61f35bb253da?utm_source=chatgpt.com "From Out-of-Memory to Optimized: Handling Java Heap ..."
[9]: https://stackoverflow.com/questions/27462061/why-does-spark-fail-with-java-lang-outofmemoryerror-gc-overhead-limit-exceeded?utm_source=chatgpt.com "Why does Spark fail with java.lang.OutOfMemoryError: GC ..."
[10]: https://spark.apache.org/docs/latest/hardware-provisioning.html "Hardware Provisioning - Spark 4.0.0 Documentation"


