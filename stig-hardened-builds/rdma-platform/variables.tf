# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------
variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID"
}

variable "region" {
  type        = string
  description = "OCI region (e.g. us-phoenix-1)"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment for all resources"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for opc on VMs and combined with generated key on BMs"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for display names (VCN, subnets, instances)"
  default     = "kove-rdma"
}

variable "availability_domain" {
  type        = string
  description = "Single AD for bastion, management VM, compute cluster, and BMs (e.g. pILZ:PHX-AD-2). Empty = derive from rdma subnet (existing VCN) or first tenancy AD."
  default     = ""
}

# ---------------------------------------------------------------------------
# Networking: create VCN vs existing
# ---------------------------------------------------------------------------
variable "use_existing_vcn" {
  type        = bool
  description = "false = create VCN with public + management + RDMA subnets; true = supply subnet OCIDs"
  default     = false
}

variable "vcn_cidr_block" {
  type        = string
  description = "VCN CIDR when creating a new VCN. Subnets: /24 at indices 1 (public), 2 (mgmt), 3 (rdma)."
  default     = "10.0.0.0/16"
}

variable "existing_vcn_id" {
  type        = string
  description = "Existing VCN OCID (informational output when using existing subnets)"
  default     = ""
}

variable "existing_public_subnet_id" {
  type        = string
  description = "Public subnet for optional bastion (must allow SSH from Internet if bastion enabled)"
  default     = ""
}

variable "existing_management_subnet_id" {
  type        = string
  description = "Private subnet for management VM (NAT egress recommended)"
  default     = ""
}

variable "existing_rdma_subnet_id" {
  type        = string
  description = "Private subnet for BM compute cluster (primary VNIC placement)"
  default     = ""
}

variable "private_subnet_ssh_sources_extras" {
  type        = string
  description = "Comma-separated CIDRs allowed SSH to private subnets in addition to VCN CIDR (when Terraform creates security lists)"
  default     = ""
}

# ---------------------------------------------------------------------------
# Optional bastion (public subnet)
# ---------------------------------------------------------------------------
variable "enable_bastion" {
  type        = bool
  description = "Create a small Oracle Linux VM in the public subnet for jump access"
  default     = true
}

variable "bastion_shape" {
  type        = string
  description = "Bastion compute shape (same VM family as stig-hardened-builds/oke-cluster worker node_pool_shape)."
  default     = "VM.Standard.E6.Flex"
}

variable "bastion_ocpus" {
  type        = number
  description = "Bastion OCPUs (E6.Flex); matches oke-cluster node_pool_ocpus default."
  default     = 2
}

variable "bastion_memory_gbs" {
  type        = number
  description = "Bastion memory in GB (E6.Flex); matches oke-cluster node_pool_memory_gbs default."
  default     = 16
}

variable "bastion_image_ocid" {
  type        = string
  description = "Optional custom image OCID for bastion; empty = latest Oracle Linux 8 for this shape"
  default     = ""
}

# ---------------------------------------------------------------------------
# Management VM (private subnet 1)
# ---------------------------------------------------------------------------
variable "management_shape" {
  type        = string
  description = "Same VM shape as oke-cluster workers by default (VM.Standard.E6.Flex)."
  default     = "VM.Standard.E6.Flex"
}

variable "management_ocpus" {
  type        = number
  description = "Matches oke-cluster node_pool_ocpus default (2)."
  default     = 2
}

variable "management_memory_gbs" {
  type        = number
  description = "Matches oke-cluster node_pool_memory_gbs default (16)."
  default     = 16
}

variable "management_image_ocid" {
  type        = string
  description = "Optional custom image; empty = latest Oracle Linux 8"
  default     = ""
}

# ---------------------------------------------------------------------------
# Management VM cloud-init (secrets stay out of Git — see README)
# ---------------------------------------------------------------------------
variable "management_cloud_init_template_path" {
  type        = string
  description = "Optional path to a cloud-init template. Empty = cloud_init/kove-rdma-cloud-init-standalone-runtime.txt. Secrets via rhsm_* and secrets.auto.tfvars. On Windows prefer forward slashes."
  default     = ""
}

variable "rhsm_org_id" {
  type        = string
  description = "RHSM organization ID; injected into cloud-init template as rhsm_org_id. Leave empty if unused."
  default     = ""
  sensitive   = true
}

variable "rhsm_activation_key" {
  type        = string
  description = "RHSM activation key; injected as rhsm_activation_key. Leave empty if unused."
  default     = ""
  sensitive   = true
}

variable "playbooks_zip_url" {
  type        = string
  description = "Optional HTTPS URL for playbooks.zip (injected into kove-rdma cloud-init). Empty skips download."
  default     = ""
}

variable "cloud_init_template_extra_vars" {
  type        = map(string)
  description = "Extra string placeholders for your management cloud-init template (e.g. other_api_token). Merged with rhsm_*; all values are treated as sensitive for plan output."
  default     = {}
  sensitive   = true
}

# ---------------------------------------------------------------------------
# BM plane (RDMA subnet) — control + scalable memory nodes
# ---------------------------------------------------------------------------
variable "bm_node_shape" {
  type        = string
  description = "Bare metal shape for control and memory nodes (oke-cluster uses VM.Standard.E6.Flex workers only; no BM in OKE node pool)."
  default     = "BM.Optimized3.36"
}

variable "bm_node_image_ocid" {
  type        = string
  description = "Custom image OCID for all BM nodes (control + memory)"
}

variable "bm_boot_volume_size_gbs" {
  type    = number
  default = 120
}

variable "memory_node_count" {
  type        = number
  description = "Number of BM.Optimized3 memory nodes (default 2 → 3 BM instances total with 1 control). Control node is always 1."
  default     = 2

  validation {
    condition     = var.memory_node_count >= 0 && var.memory_node_count <= 32
    error_message = "memory_node_count must be between 0 and 32."
  }
}

variable "bm_capacity_reservation_id" {
  type    = string
  default = ""
}

variable "bm_generic_platform_config" {
  type        = bool
  description = "GENERIC_BM platform_config (often must stay false for BM.Optimized3 on compute cluster)"
  default     = false
}

variable "bm_smt_enabled" {
  type    = bool
  default = true
}

variable "bm_numa_nodes_per_socket" {
  type    = string
  default = "NPS1"
}

variable "use_compute_agent" {
  type        = bool
  description = "Oracle Cloud Agent HPC RDMA plugins on BMs"
  default     = false
}

variable "bm_imds_ssh_key_bootstrap" {
  type        = bool
  description = "First-boot script to copy SSH keys from IMDS to opc/cloud-user/ec2-user (custom RHEL images)"
  default     = true
}

variable "cluster_network_create_timeout" {
  type        = string
  description = "Per-BM instance create timeout"
  default     = ""
}

variable "create_bm_console_connections" {
  type        = bool
  description = "Create OCI instance console connections for each BM (serial/VNC over SSH tunnel)"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Freeform tags applied to major resources"
  default     = {}
}
