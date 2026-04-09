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
  description = "Dedicated OKE VCN CIDR when use_existing_vcn is false. Ignored when attaching to an existing VCN (CIDR comes from data source)."
  default     = "10.20.0.0/16"
}

variable "use_existing_vcn" {
  type        = bool
  description = "true = create OKE subnets inside an existing VCN (e.g. stig-hardened-builds/rdma-platform). Supply route table OCIDs from rdma outputs."
  default     = false
}

variable "existing_vcn_id" {
  type        = string
  description = "Existing VCN OCID (e.g. output vcn_id from rdma-platform)."
  default     = ""
}

variable "existing_public_route_table_id" {
  type        = string
  description = "Public route table in that VCN (rdma output public_route_table_ocid when rdma created the VCN)."
  default     = ""
}

variable "existing_private_route_table_id" {
  type        = string
  description = "Private NAT route table (rdma output private_route_table_ocid when rdma created the VCN)."
  default     = ""
}

variable "oke_vcn_subnet_index_base" {
  type        = number
  description = "When use_existing_vcn: /24 index under the VCN CIDR for OKE API slice. Default 4 => 10.0.4.0/24 (and 10.0.5, 10.0.6 for LB/workers) in a /16 VCN where rdma uses indices 1–3."
  default     = 4
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
  description = "Worker shape — kept in lockstep with stig-hardened-builds/rdma-platform bastion/management (VM.Standard.E6.Flex)."
  default     = "VM.Standard.E6.Flex"
}

variable "node_pool_ocpus" {
  type        = number
  description = "Matches rdma-platform bastion_ocpus / management_ocpus default (2)."
  default     = 2
}

variable "node_pool_memory_gbs" {
  type        = number
  description = "Matches rdma-platform bastion_memory_gbs / management_memory_gbs default (16)."
  default     = 16
}

variable "node_pool_size" {
  type        = number
  description = "Worker count (single AD). Default 3 aligns with rdma-platform default BM footprint (1 control + 2 memory nodes = 3 hosts), not shape-for-shape on bare metal."
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

variable "worker_ssh_ingress_cidr" {
  type        = string
  description = "When Terraform creates the VCN: CIDR allowed to SSH (TCP 22) to worker nodes on their subnet security list (tighten like oci-hpc `ssh_cidr`). Ignored for existing VCN (your SLs apply)."
  default     = "0.0.0.0/0"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Freeform tags on major resources"
}
