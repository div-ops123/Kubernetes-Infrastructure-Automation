module "vpc" {
  source = "./modules/networking"
}

module "compute" {
  source = "./modules/compute"
  
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids = module.vpc.public_subnet_ids
  k8s_nodes_sg_id    = module.vpc.k8s_nodes_sg_id  
  control_node_sg_id = module.vpc.control_node_sg_id
}

# Define a StorageClass for dynamic EBS volume provisioning
resource "kubernetes_storage_class" "ebs_sc" {
  metadata {
    name = "ebs-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"  # Makes this the default StorageClass
    }
  }
  storage_provisioner = "ebs.csi.aws.com"  # CSI driver for AWS EBS. requires the EBS CSI driver to be installed on your cluster
  parameters = {
    type = "gp3"  # General Purpose SSD (gp3)
  }
  volume_binding_mode = "WaitForFirstConsumer"  # Delays binding until a pod needs it
}

