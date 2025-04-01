module "vpc" {
  source = "./modules/networking"
}

module "compute" {
  source = "./modules/compute"
  
  private_subnet_ids = module.vpc.private_subnet_ids
  k8s_nodes_sg_id    = module.vpc.nodes_sg_id  
}