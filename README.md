### Project Overview: Kubernetes(kubeadm) Infrastructure Automation on AWS

**Disclaimer**: Application code by Author: Ryan Almeida
📌 GitHub Profile: Ryan Almeida[https://github.com/ryan-almeida]

**Goal**: Provision a scalable, containerized note-taking app on Kubernetes, deployed on EC2 instances using Terraform for infrastructure, Ansible for configuration management, and a CI/CD pipeline (Jenkins + Harness) for automation, using Terraform modules for networking and compute, and remote state in S3/DynamoDB.

**Components**:
- **Infrastructure (Terraform)**:
  - VPC, Subnets, Security Groups, Internet Gateway (IGW), Route Tables
  - EC2 instances for Kubernetes nodes
  - Auto Scaling Group (ASG) for worker nodes
  - Application Load Balancer (ALB)
  - S3 bucket and DynamoDB table for Terraform state

- **Configuration Management (Ansible)**:
  - Kubernetes installation and node setup
  - Application deployment configurations

- **Orchestration (Kubernetes)**:
  - Node.js app running as a containerized service
  - Ingress controller for routing

- **CI/CD (Jenkins + Harness)**:
  - Jenkins pipeline for building and testing
  - Harness for automated deployments

- **State**: 
  - S3 bucket and DynamoDB table for Terraform state.

---

### Project Structure
Following best practices:

```
./
├── application-code/          # Node.js note-app source code
│   ├── src/                  # App source files (e.g., server.js)
│   ├── package.json          # Node.js dependencies and scripts
│   ├── Dockerfile            # Docker image definition for the app
│   └── .dockerignore         # Ignore files for Docker build
├── terraform/                # Terraform infra code
│   ├── main.tf               # Root module: Calls networking and compute modules
│   ├── variables.tf          # Root-level variables
│   ├── outputs.tf            # Root-level outputs (e.g., cluster IPs)
│   ├── provider.tf           # AWS provider config
│   ├── versions.tf           # Terraform and provider versions, S3 backend
│   ├── bootstrap/            # Bootstrap module for remote state management
│   │   ├── main.tf           # Manages S3 backend and DynamoDB for state locking
│   └── modules/
│       ├── networking/       # VPC, subnets, IGW, etc.
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── compute/          # EC2 instances for Kubernetes nodes
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── ansible/                  # Ansible config for Kubernetes setup
│   ├── inventory.yml         # List of EC2 instances (dynamically populated)
│   ├── playbooks/
│   │   ├── install-k8s.yml   # Install Kubernetes (kubeadm, Docker, etc.)
│   │   └── configure-cluster.yml  # Join nodes to the cluster
│   └── roles/                # Reusable Ansible roles (optional)
│       ├── kubernetes/
│       │   ├── tasks/
│       │   ├── templates/
│       │   └── vars/
├── kubernetes/               # Kubernetes manifests for the note-app
│   ├── deployment.yml        # Deployment for the Node.js app
│   ├── service.yml           # Service to expose the app (e.g., LoadBalancer)
│   └── configmap.yml         # Optional: Config for the app (if needed)
├── .gitignore                # Ignore transient files
└── README.md                 # Project overview and setup instructions
```

#### Prerequisites

### aws, aws cli, and terraform installed and set up

#### Deployment Guide

## A. Configuring Remote State Management with S3 and DynamoDB

**Run the Bootstrap**:
1. Navigate to the `bootstrap/` directory:
   ```bash
   cd bootstrap
   ```
2. Initialize and apply:
   ```bash
   terraform init
   terraform apply
   ```
   - Type `yes` when prompted to create the resources.
3. This creates the S3 bucket and DynamoDB table, storing the state locally in `bootstrap/terraform.tfstate`.

**Initialize the Remote Backend**:
1. Navigate to your main project directory

2. Run:
   ```bash
   terraform init
   ```
   - Terraform will detect the backend configuration and prompt you to migrate any existing local state to S3. Type `yes`.

### Why This Works
- The bootstrap step creates the S3 bucket and DynamoDB table independently.
- The main project then uses these resources to store its state remotely, with DynamoDB providing state locking to prevent concurrent modifications.


## B. 

`application-code/`
- Test locally: `docker build -t note-app . && docker run -p 3000:3000 note-app`.


`terraform/`
- It can assign static private IPs to avoid changes when restarting.
- Output public IPs for Ansible inventory.


`ansible/`
- Use Ansible roles for modularity (e.g., `kubernetes` role).
- Test playbook locally first with a single VM if possible.


`kubernetes/`
- Use `kubectl apply -f kubernetes/` to deploy manually first.


CI/CD (Jenkins + Harness)
- **CI (Jenkins)**:
  - **Pipeline**: `Jenkinsfile` to `npm test`, `docker build`, `docker push` to a registry (e.g., Docker Hub).
- **CD (Harness)**:

  - **Setup**: Install Jenkins on a separate EC2 or locally.
  - Start with manual `kubectl` deployment, then automate with Jenkins/Harness.

---
**Communication**:
The nodes have their communication routes via the `route tables`:
- **Master ↔ Workers**: Both in private subnets, use 10.0.0.0/16 → local to talk internally (e.g., API on 6443, pod traffic).
- **ALB → Nodes**: ALB in public subnets (via IGW) sends traffic to nodes in private subnets (via Security Group rules, e.g., NodePort range).
- **Nodes → Internet**: Not yet—private route table lacks 0.0.0.0/0 → nat-<id> (no NAT Gateway), so no outbound internet access (we’ll add this later if needed for Docker pulls).

---

### Workflow Steps
1. **Terraform**:
   - Provision VPC, subnets, and 3 EC2 instances (1 master, 2 workers).
   - Output IPs for Ansible.
2. **Ansible**:
   - Run `install-k8s.yml` to install Kubernetes.
   - Run `configure-cluster.yml` to set up the cluster.
3. **CI (Jenkins)**:
   - Build Docker image from `application-code/`.
   - Push to a registry.
4. **Kubernetes**:
   - Deploy the image manually with `kubectl` to test.
5. **CD (Harness)**:
   - Automate deployment to Kubernetes.

---