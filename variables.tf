# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "cluster-name"{
  description = "Name of the EKS cluster"
  type        = string
  default     = "aep-eks"
}

variable "env_name"{
  description = "Name of the environment"
  type        = string
  default     = "dev"
}
