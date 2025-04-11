### Project Overview: End-To-End DevOps Kubernetes Project with Terraform Ansible Jenkins and ArgoCD

# PERSUASIVE CONTENTS

**Goal**: Provision a scalable, containerized note-taking app on Kubernetes, deployed on EC2 instances using Terraform for infrastructure, Ansible for configuration management, and a CI/CD pipeline (Jenkins + Harness) for automation, using Terraform modules for networking and compute, and remote state in S3/DynamoDB.

## Kubernetes Setup:
Self-Managed K8s: 3 EC2 instances (1 control plane, 2 workers?) running kubeadm.

**Components**:
- **Infrastructure (Terraform)**:
  - VPC, Subnets, Security Groups, Internet Gateway (IGW), Route Tables
  - EC2 instances for Kubernetes nodes
  - Auto Scaling Group (ASG) for worker nodes
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
├── application-code/          # Node.js url-shortener source code
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
└── README.md                 # Project overview and setup instructions
```

#### Prerequisites


### Workflow Steps
1. **Terraform**:
   - Provision VPC, subnets, 
   - Output IPs for Ansible.
2. **Ansible**:
   - ansible/playbooks/install-k8s.yml - to install Kubernetes.
   - ansible/playbooks/configure-cluster.yml - to set up the cluster.
3. **CI (Jenkins)**:
   - Build Docker image.
   - Push to a registry.
4. **Kubernetes**:
   - Deploy the image manually with `kubectl` to test.
5. **CD (Harness)**:
   - Automate deployment to Kubernetes.

---