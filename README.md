### Project Overview: Kubernetes(kubeadm) Infrastructure Automation on AWS

**Goal**: Provision a scalable, containerized note-taking app on Kubernetes, deployed on EC2 instances using Terraform for infrastructure, Ansible for configuration management, and a CI/CD pipeline (Jenkins + Harness) for automation, using Terraform modules for networking and compute, and remote state in S3/DynamoDB.

## Kubernetes & Ansible:
One Control Node, One Master Node, and a Highly Available Worker Node setup across Two AZs.

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

### Prerequisites:
1. Install AWS CLI, and Configure Credentials.
2. [Terraform Installed](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
3. Ansible installed (e.g via `pip3 install ansible --user`)
4. Change the home_dir in terraform/modules/compute/variables.tf

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


## B. Change the path in
- ansilbe_ssh_private_key_file
- ~/.ssh/config   - change the private ips of k8s nodes to your output from terraform. Get the private IPs from your Terraform outputs (e.g bash: terraform output worker_instance_ips in the terraform/ directory).

## C. Enable SSH from Control Node to Kubernetes Nodes

### Copy the Private Key to the Control Node:
Since the Kubernetes nodes uses `note-app-key.pub`, you need the matching private key (`url-shortener-key`) on the control node to SSH into them.

1. **Step 1**: Locate the Private Key on the machine where you ran `ssh-keygen` e.g VM1

2. **Step 2**: Copy the Private Key to the Control Node
From VM1, SCP the private key to the control node:

- Since `url-shortener-key` is the private key that matches control-node’s public key (from the AWS key pair), use it directly in the scp command from VM1. Example:

```bash
scp -i /home/ec2-user/.ssh/url-shortener-key /home/ec2-user/.ssh/url-shortener-key ubuntu@<public-ip>:/home/ubuntu/.ssh/url-shortener-key
```

- **-i /home/ec2-user/.ssh/url-shortener-key**: Specifies the private key to authenticate with vm2.
- **Source**: /home/ec2-user/.ssh/url-shortener-key (the file to copy).
- **Destination**: ubuntu@1<public-ip>:/home/ubuntu/.ssh/url-shortener-key (where it’s going on vm2).

### If It Fails:
Set File Permissions:
On vm1, ensure url-shortener-key has the right permissions:
```bash
chmod 600 /home/ec2-user/.ssh/note-app-key
```

`application-code/`
- Test locally: `docker build -t url-shortener . && docker run -p 3000:3000 url-shortener`.


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
Terraform Taint:
`terraform taint module.compute.aws_autoscaling_group.workers` → Marks ASG for recreation.
terraform apply → Rebuilds ASG and instances.


Next Steps:

Ansible Setup

Automate the Process. Grok query - Step 2: Fetch Terraform Outputs
- Dynamically fetch the private IP addresses of your nodes from Terraform outputs and use them in your Ansible inventory.
- Add a step in your workflow (e.g., a shell script) to regenerate terraform_outputs.json after terraform apply.


Containerize App
k8s deployment
cicd

--- 
- Graceful shutdown.txt

- GPT query:

2️⃣ Configure Ansible to Use the Control Node as a Bastion Host

---

### Workflow Steps
1. **Terraform**:
   - Provision VPC, subnets, 
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