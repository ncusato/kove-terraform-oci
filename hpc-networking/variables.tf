# ---------------------------------------------------------------------------
# OCI / stack identity (Resource Manager pre-fills tenancy and region)
# ---------------------------------------------------------------------------
variable "tenancy_ocid" {
  type        = string
  description = "Tenancy OCID."
}

variable "region" {
  type        = string
  description = "Region identifier (e.g. us-ashburn-1)."
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment where the VCN and networking resources are created."
}

# ---------------------------------------------------------------------------
# Naming (display names in console; dns_label must be unique per VCN)
# ---------------------------------------------------------------------------
variable "name_prefix" {
  type        = string
  description = "Prefix for default display names (VCN, gateways, route tables, subnets, security lists)."
  default     = "hpc-net"
}

variable "vcn_display_name" {
  type        = string
  description = "Override VCN display name. Empty = \"<name_prefix>-vcn\"."
  default     = ""
}

variable "public_subnet_display_name" {
  type        = string
  description = "Override public subnet display name. Empty = \"<name_prefix>-public\"."
  default     = ""
}

variable "private_subnet_1_display_name" {
  type        = string
  description = "Override first private subnet. When consolidated: the only private subnet. When separate: management-style subnet. Empty = generated name."
  default     = ""
}

variable "private_subnet_2_display_name" {
  type        = string
  description = "Override second private subnet (separate management + RDMA layout only). Empty = \"<name_prefix>-private-hpc\"."
  default     = ""
}

# ---------------------------------------------------------------------------
# CIDR layout (fixed pattern for ORM clarity — see outputs after apply)
# ---------------------------------------------------------------------------
variable "vcn_cidr_block" {
  type        = string
  description = "VCN IPv4 CIDR. Subnets are carved as /24s: **index 1** = public, **index 2** = first private, **index 3** = second private (only when using separate management and RDMA subnets). Example VCN 10.0.0.0/16 → public 10.0.1.0/24, private A 10.0.2.0/24, private B 10.0.3.0/24."
  default     = "10.0.0.0/16"
}

variable "private_subnet_layout" {
  type        = string
  description = "Must be exactly one of: \"Consolidate management and RDMA into one private subnet\" (single private /24) or \"Separate private subnets for management and RDMA\" (two private /24s, same pattern as stig-hardened-builds/rdma-platform). Resource Manager shows these as a dropdown."
  default     = "Separate private subnets for management and RDMA"

  validation {
    condition = (
      var.private_subnet_layout == "Consolidate management and RDMA into one private subnet" ||
      var.private_subnet_layout == "Separate private subnets for management and RDMA"
    )
    error_message = "private_subnet_layout must be \"Consolidate management and RDMA into one private subnet\" or \"Separate private subnets for management and RDMA\"."
  }
}

variable "private_subnet_ssh_sources_extras" {
  type        = string
  description = "Comma-separated extra CIDRs allowed to SSH (TCP 22) into private subnets, in addition to traffic already allowed from the VCN CIDR."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Freeform tags applied to created resources."
  default     = {}
}
