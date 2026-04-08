variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID"
}

variable "region" {
  type        = string
  description = "OCI region (e.g. us-ashburn-1)"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment for cluster, node pool, and networking"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for worker nodes (opc)"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource display names"
  default     = "kove-oke"
}

variable "vcn_cidr_block" {
  type        = string
  description = "Dedicated OKE VCN CIDR (avoid overlap with peered networks / rdma-platform 10.0.0.0/16)"
  default     = "10.20.0.0/16"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version (e.g. v1.31.1). Empty = newest supported version from OCI for this compartment."
  default     = ""
}

variable "availability_domain" {
  type        = string
  description = "AD for worker placement (e.g. kIdk:US-ASHBURN-AD-1). Empty = first AD in region."
  default     = ""
}

variable "node_pool_shape" {
  type        = string
  description = "Worker shape (Flex shapes need node_pool_ocpus / node_pool_memory_gbs)"
  default     = "VM.Standard.E6.Flex"
}

variable "node_pool_ocpus" {
  type    = number
  default = 2
}

variable "node_pool_memory_gbs" {
  type    = number
  default = 16
}

variable "node_pool_size" {
  type        = number
  description = "Worker count (single placement config / one AD)"
  default     = 3

  validation {
    condition     = var.node_pool_size >= 1 && var.node_pool_size <= 32
    error_message = "node_pool_size must be between 1 and 32."
  }
}

variable "public_control_plane_endpoint" {
  type        = bool
  description = "If true, Kubernetes API endpoint gets a public IP on the endpoint subnet"
  default     = true
}

variable "worker_image_id" {
  type        = string
  description = "Optional custom image OCID for workers; empty = first IMAGE source from OCI node pool options (Oracle Linux)"
  default     = ""
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Freeform tags on major resources"
}
