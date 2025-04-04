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