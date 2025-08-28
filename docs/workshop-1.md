# Apache Spark on Kubernetes Workshop
## Introduction

Apache Spark is a popular distributed data processing engine, and Kubernetes is a powerful container orchestration platform. In this workshop, we’ll explore why containerization and Kubernetes are important for running Spark applications, and how to deploy Spark on Kubernetes. The goal is to help data engineers (who may not be DevOps experts) understand the benefits of containerizing Spark jobs, using Kubernetes for orchestration, and the pros and cons of Spark on Kubernetes. We’ll also walk through a hands-on demo of running a Spark job on a local Kubernetes cluster, so you can see it in action.

## Why Containerize Spark Applications?

Containerization means packaging an application with its dependencies into a lightweight, portable container image. This approach offers several benefits for Spark applications:

- **Environment consistency**: A container image encapsulates all dependencies (libraries, Spark version, etc.), ensuring the application runs the same everywhere. This avoids the “it works on my machine” problem and guarantees consistency across dev, test, and prod.
- **Isolation**: Each Spark job can run in its own container, isolated from other jobs and the host system. This prevents dependency conflicts and allows different jobs to have different Spark or Python versions without interference.
- **Reproducibility & agility**: Containers enable repeatable and reliable build workflows. You build the image once and run it anywhere (locally or at scale). This speeds up iteration; many teams report faster development cycles using Docker with Spark.
- **Portability**: A Spark job packaged in a Docker container can be deployed on any environment that supports containers (on‑premises or cloud), easing migration between environments or providers.
- **Dependency management**: Bake required libraries into the image to avoid flaky init scripts and ensure executors have the needed packages.

In short, containerizing Spark jobs makes them more portable, consistent, and easier to deploy, while reducing the manual work needed to configure environments.

## Why Use Kubernetes for Spark?

If containers package our Spark applications, Kubernetes (K8s) is the platform that runs and manages those containers across a cluster of machines. Kubernetes provides an “operating system” for clusters, automating deployment, scheduling, scaling, and recovery of containerized applications. Here’s why Kubernetes is a great fit for Spark:

- **Orchestration & scheduling**: Kubernetes schedules Spark driver and executor pods onto cluster nodes, restarts on failure, and can auto‑scale. Kubernetes acts as Spark’s cluster manager (replacing YARN or standalone mode) and efficiently deploys and heals pods.
- **Resource efficiency**: Kubernetes encourages a shared cluster where multiple Spark jobs run side by side in namespaces, with resources dynamically allocated and reclaimed. This avoids per‑job transient clusters and yields better bin‑packing and cost efficiency.
- **Replacing YARN limitations**: YARN often involves static partitioning and job‑by‑job cluster overhead. Modern Spark versions have strong K8s support, and many orgs are moving Spark scheduling to Kubernetes.
- **Unified infrastructure & ecosystem**: Reuse Kubernetes features like namespaces, RBAC, and common logging/monitoring stacks (Prometheus/Grafana, ELK) for Spark workloads.
- **Scalability & flexibility**: Scale Spark applications horizontally and run them alongside other workloads on the same cluster, improving overall utilization.

In summary, once Spark jobs are containerized, Kubernetes provides the automation and infrastructure‑as‑code needed to deploy Spark reliably at scale, and integrates Spark into the broader cloud‑native ecosystem.

## How Spark Runs on Kubernetes (Architecture)

In Spark’s Kubernetes mode, the Kubernetes cluster acts as the cluster manager for Spark (similar to YARN or standalone master). High‑level flow when you run a Spark job on K8s:

- **Spark driver pod**: Submitting a Spark application with Kubernetes as the master launches the Spark driver inside a Kubernetes pod. The driver controls the Spark application.
- **Executor pods**: The driver requests executor pods via the Kubernetes API. Each executor runs in its own pod, scheduled onto nodes, and connects back to the driver to process tasks.
- **Dynamic lifecycle**: With Spark 3.x dynamic allocation, executors can scale up/down during runtime. When the job finishes, executor pods terminate and free resources. The driver pod eventually moves to a Completed state before garbage collection.
- **Kubernetes as scheduler**: Kubernetes places pods on nodes per requested CPU/memory and recovers on failures. Spark’s K8s backend works on a desired‑state principle where Kubernetes maintains the requested number of executors.
- **Networking and storage**: Driver and executors communicate over the cluster network. Data is typically read from external systems (HDFS, cloud storage) over the network; volumes and secrets can be mounted using Kubernetes primitives.

In essence, Spark‑on‑Kubernetes eliminates manual cluster management: you submit a job and Kubernetes launches the driver/executors on demand and cleans them up afterward.

## Pros of Running Spark on Kubernetes

Running Spark on Kubernetes can offer many advantages compared to traditional deployments:

- **Portable, consistent environments**: Containerizing Spark apps yields portable and reproducible environments across local, on‑prem, and cloud, reducing configuration drift.
- **Dependency isolation**: Each Spark app runs fully isolated in its own containers. Different jobs can use different Spark/Python versions or dependency sets without conflict.
- **Dynamic resource sharing = efficiency & cost savings**: A shared resource pool with fine‑grained dynamic allocation improves utilization and can significantly reduce costs. Executors are bin‑packed tightly and resources recycled quickly.
- **Scalability and auto‑scaling**: Launch many executors in parallel and integrate with cluster autoscalers to add/remove nodes based on demand.
- **Unified platform & ecosystem**: Use the same infra and tools for Spark as other apps. Leverage namespaces/RBAC, unified monitoring/logging, and GitOps‑style workflows.
- **Cloud‑agnostic, less lock‑in**: Kubernetes runs everywhere, reducing dependence on vendor‑specific Spark services.
- **Mature performance**: With Spark 3.x, the K8s backend is production‑ready and typically achieves performance parity with YARN.

## Cons and Challenges of Spark on Kubernetes

Despite the benefits, be aware of these drawbacks and challenges:

- **Steep learning curve**: Kubernetes introduces new concepts (pods, services, YAML) and tooling that require upskilling for many data teams.
- **Cluster setup and maintenance**: Even with managed K8s, you must configure nodes, networking, storage, autoscaling, registries, Spark History Server, monitoring, etc., to be production‑ready.
- **Migrating existing workloads**: Moving from YARN/other platforms to K8s requires adapting jobs to container images and rethinking I/O, security, and performance tuning.
- **Monitoring & debugging complexity**: You’ll monitor both Spark and K8s layers (pod health, scheduling, resources) and may need specialized observability.
- **Security and configuration**: Ensure correct RBAC, pod security, image hygiene, service account permissions, and DNS/networking for executors to register.
- **Spark version constraints**: Prefer Spark 3.1+ for stable Kubernetes mode (older versions lack critical features).

Despite these challenges, many organizations find the benefits outweigh the cons, especially with the right tooling (e.g., the Spark Operator) or managed services.

## Hands-On Demonstration: Running Spark on Kubernetes

Now let’s outline a simple hands‑on demo to illustrate Spark on Kubernetes using Minikube (a local single‑node Kubernetes).

### Step 1: Set up a Local Kubernetes Cluster

Install Minikube and kubectl on your machine. Start Minikube with enough resources for Spark; for example, allocate at least 3 CPUs and 4GB of RAM:

```bash
minikube start --cpus 3 --memory 4096
```

Verify it’s running:

```bash
kubectl cluster-info
kubectl get nodes
```

### Step 2: Prepare a Spark Docker Image

Spark on K8s requires a container image for the Spark driver and executors that includes Spark itself. You have options:

- **Build your own Spark image** using the Spark distribution’s Dockerfiles and helper script:

```bash
./bin/docker-image-tool.sh -t spark-k8s-demo -r <your_dockerhub_username> build
```

- **Use a pre‑built image** from a trusted repository (e.g., Spark Operator images for Spark 3.x). Choose an image matching your Spark version.

For this demo, assume a pre‑built image. Note the image name/tag; you’ll need it when submitting the job.

### Step 3: Configure Kubernetes Permissions

By default, the Spark driver uses the default namespace/service account with limited permissions. Ensure the driver can create/manage executor pods. For a local setup, create a dedicated namespace and service account:

```bash
kubectl create namespace spark 
kubectl create serviceaccount spark -n spark
```

Bind a role that allows creating pods and services (quick local option: grant the built‑in edit role on the namespace):

```bash
kubectl create clusterrolebinding spark-role --clusterrole=edit \
    --serviceaccount=spark:spark --namespace=spark
```

In production, scope permissions more tightly.

### Step 4: Submit a Spark Job to Kubernetes

With the cluster up, image available, and permissions set, run Spark’s built‑in Spark Pi example (computes an approximation of π):

```bash
$SPARK_HOME/bin/spark-submit \
 --master k8s://https://<MINIKUBE-CLUSTER-IP>:8443 \
 --deploy-mode cluster \
 --name spark-pi-demo \
 --class org.apache.spark.examples.SparkPi \
 --conf spark.executor.instances=2 \
 --conf spark.kubernetes.container.image=<your-spark-image> \
 --conf spark.kubernetes.namespace=spark \
 --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
 local:///opt/spark/examples/jars/spark-examples_2.12-3.1.1.jar
```

Explanation:

- `--master k8s://https://...` points Spark to the Kubernetes API server (see `kubectl cluster-info`).
- `--deploy-mode cluster` runs the Spark driver on Kubernetes.
- `--conf spark.executor.instances=2` sets two executors (adjust as resources allow).
- `--conf spark.kubernetes.container.image=<image>` sets the Spark image used by driver/executors.
- `--conf spark.kubernetes.namespace` and `--conf spark.kubernetes.authenticate.driver.serviceAccountName` ensure correct namespace and permissions.
- The application jar path uses `local://` to reference a jar inside the image.

Kubernetes should create a `spark-pi-demo-driver` pod in the `spark` namespace and then spawn executor pods.

### Step 5: Monitor the Spark Application

Use kubectl to observe progress:

- **List pods**:

```bash
kubectl get pods -n spark
```

- **Tail driver logs**:

```bash
kubectl logs -f spark-pi-demo-driver -n spark
```

Optionally, port‑forward the Spark UI if exposed and view it at http://localhost:4040.

The Spark Pi job is short; within a minute it should finish. Executor pods complete and terminate; the driver pod typically remains in Completed for a while.

### Step 6: Cleanup

Delete the driver pod or the entire namespace:

```bash
kubectl delete pod <driver-pod-name> -n spark
kubectl delete namespace spark
```

Stop Minikube when done:

```bash
minikube stop
```

Note: This demo uses a single‑node cluster for simplicity. In production, use a multi‑node managed K8s (EKS/GKE/AKS), ensure appropriate RBAC, and consider the Spark Operator to manage Spark applications declaratively.

## Conclusion

In this workshop, we covered how containerization and Kubernetes can modernize the way you run Apache Spark:

- **Containers solve deployment headaches** by packaging Spark jobs into portable, consistent units that run anywhere.
- **Kubernetes provides automation** to deploy and manage these containers at scale, improving utilization, flexibility, and integration with cloud‑native tooling.

Running Spark on Kubernetes offers clear advantages in efficiency, isolation, and operational consistency. While there’s added complexity, good planning and tooling make adoption practical.

## References

- Apache Spark documentation: https://spark.apache.org
- ChaosGenius blog: https://chaosgenius.io
- Pepperdata articles: https://www.pepperdata.com
- Spot.io blog: https://spot.io
- Misc. tutorials and community posts (e.g., Medium) on Spark‑on‑Kubernetes
