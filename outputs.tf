# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0
output "vpc_id" {
  description = "vpn id"
  value       = module.vpc.vpc_id
}
output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnet_cidrs" {
  description = "List of CIDR blocks of the public subnets"
  value       = module.vpc.public_subnets_cidr_blocks
}

output "private_subnet_cidrs" {
  description = "List of CIDR blocks of the private subnets"
  value       = module.vpc.private_subnets_cidr_blocks
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}