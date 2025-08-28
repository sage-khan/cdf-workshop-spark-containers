
# Findings

- I populated [requirements/requirements-apt.txt](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/requirements/requirements-apt.txt:0:0-0:0) with the core tools and optional extras for your local demo pipeline.
- File updated: [requirements/requirements-apt.txt](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/requirements/requirements-apt.txt:0:0-0:0)

Contents added:
- Core: kubectl, kind, docker.io, make, git, curl, jq
- Optional (Minikube): minikube
- Optional security/policy (comments): syft, trivy, cosign, conftest
- Common helpers: ca-certificates, gnupg, apt-transport-https

# Why these

- __kubectl, kind, docker.io, make, git, curl, jq__: required by your [Makefile](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/Makefile:0:0-0:0) and local workflow.
- __minikube__: only if you present the Minikube path.
- __syft, trivy, cosign, conftest__: used by optional `make sbom`, `make scan`, `make sign`, `make policy`.
- __certs/gnupg/https__: for adding vendor APT repos securely.

# Install tips (Ubuntu/Debian)

Some tools aren’t in default repos. Short references:

- Docker Engine (community repo recommended over `docker.io`):
  ```bash
  sudo apt-get update
  sudo apt-get install -y ca-certificates gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
  ```

- kubectl (Kubernetes apt repo):
  ```bash
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
    https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update && sudo apt-get install -y kubectl
  ```

- kind (binary):
  ```bash
  curl -Lo kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
  chmod +x kind && sudo mv kind /usr/local/bin/
  kind version
  ```

- Minikube (optional):
  ```bash
  curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  chmod +x minikube && sudo mv minikube /usr/local/bin/
  minikube version
  ```

- Security/policy tools (optional; vendor repos vary):
  - syft: https://github.com/anchore/syft
  - trivy: https://aquasecurity.github.io/trivy
  - cosign: https://docs.sigstore.dev/cosign/installation/
  - conftest: https://www.conftest.dev/install/

# Next steps

- If you want, I can also add a simple install script that reads [requirements/requirements-apt.txt](cci:7://file:///home/metanet/ProgramFiles/cdf-demo-kubernetes/requirements/requirements-apt.txt:0:0-0:0) and installs what’s available, then prints guidance for the ones that need vendor repos.