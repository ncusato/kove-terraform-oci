variable "tenancy_ocid" {
  type        = string
  description = "OCI Tenancy OCID"
}

variable "region" {
  type        = string
  description = "OCI region (e.g. us-ashburn-1)"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment to host the cluster"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key to inject into instances"
}

variable "bm_node_image_ocid" {
  type        = string
  description = "RHEL 8.8 image OCID for BM.Optimized3.36 nodes (cluster network)"
}

variable "head_node_image_ocid" {
  type        = string
  description = "Image OCID for the head node. If empty, uses latest Oracle Linux 8 (so head needs no RHSM); Ansible registers RHEL on BM only. Set to override (e.g. specific OL version)."
  default     = ""
}

variable "bm_node_count" {
  type        = number
  description = "Number of BM nodes in the cluster network (RDMA)"
  default     = 4
}

# -------------------------------------------------------------------
# Networking control
# -------------------------------------------------------------------

variable "use_existing_vcn" {
  type        = bool
  description = "If true, use existing VCN and subnets; if false, create new networking."
  default     = false
}

variable "existing_vcn_id" {
  type        = string
  description = "Existing VCN OCID (required if use_existing_vcn = true)"
  default     = ""
}

variable "existing_public_subnet_id" {
  type        = string
  description = "Existing public subnet OCID for head node"
  default     = ""
}

variable "existing_private_subnet_id" {
  type        = string
  description = "Existing private subnet OCID for BM nodes"
  default     = ""
}

# Simple validation to help catch misconfig
locals {
  networking_config_valid = var.use_existing_vcn ? (
    length(var.existing_vcn_id) > 0 &&
    length(var.existing_public_subnet_id) > 0 &&
    length(var.existing_private_subnet_id) > 0
  ) : true
}

# Terraform doesn't allow top-level validation on locals directly,
# but you can add a "fake" resource if you want hard enforcement.
# For now, we rely on you to set the IDs correctly when use_existing_vcn = true.

# -------------------------------------------------------------------
# Ansible from head node (Resource Manager)
# -------------------------------------------------------------------

variable "run_ansible_from_head" {
  type        = bool
  description = "If true, head node user_data runs Ansible at first boot (instance principal required; see README)."
  default     = false
}

variable "rhsm_username" {
  type        = string
  description = "RHSM username for RHEL registration (used when run_ansible_from_head = true)."
  default     = ""
  sensitive   = true
}

variable "rhsm_password" {
  type        = string
  description = "RHSM password for RHEL registration (used when run_ansible_from_head = true)."
  default     = ""
  sensitive   = true
}

variable "rdma_ping_target" {
  type        = string
  description = "RDMA interface ping target IP (e.g. another BM node's secondary VNIC IP) for playbook when run_ansible_from_head = true."
  default     = ""
}

variable "instance_ssh_user" {
  type        = string
  description = "SSH user for BM nodes (e.g. cloud-user for RHEL). Used for head too unless head_node_ssh_user is set."
  default     = "cloud-user"
}

variable "head_node_ssh_user" {
  type        = string
  description = "SSH user for the head node only (e.g. opc for Oracle Linux). If empty, uses instance_ssh_user."
  default     = ""
}
