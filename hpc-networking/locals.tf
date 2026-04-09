locals {
  common_tags = var.tags

  # Single OSN object from data source (matches oci-hpc network.tf private route table).
  oracle_services_network = data.oci_core_services.oracle_services_network.services[0]

  private_ssh_extra_cidrs = compact([for s in split(",", var.private_subnet_ssh_sources_extras) : trimspace(s) if trimspace(s) != ""])

  dns_safe_prefix = substr(replace(replace(lower(trimspace(var.name_prefix)), "-", ""), "_", ""), 0, 12)
  vcn_dns_label   = length(local.dns_safe_prefix) > 0 ? local.dns_safe_prefix : "hpcnetwork"

  dhcp_search_domain = format("%s.oraclevcn.com", local.vcn_dns_label)

  public_subnet_cidr  = cidrsubnet(var.vcn_cidr_block, 8, 1)
  private_subnet_cidr = cidrsubnet(var.vcn_cidr_block, 8, 2)
  private_hpc_cidr    = cidrsubnet(var.vcn_cidr_block, 8, 3)

  consolidate_private = var.private_subnet_layout == "Consolidate management and RDMA into one private subnet"

  private_subnet_count = local.consolidate_private ? 1 : 2

  private_subnet_cidrs = local.consolidate_private ? [local.private_subnet_cidr] : [local.private_subnet_cidr, local.private_hpc_cidr]

  vcn_name = trimspace(var.vcn_display_name) != "" ? trimspace(var.vcn_display_name) : "${var.name_prefix}-vcn"

  public_subnet_name = trimspace(var.public_subnet_display_name) != "" ? trimspace(var.public_subnet_display_name) : "${var.name_prefix}-public"

  private_subnet_names = local.consolidate_private ? [
    trimspace(var.private_subnet_1_display_name) != "" ? trimspace(var.private_subnet_1_display_name) : "${var.name_prefix}-private"
    ] : [
    trimspace(var.private_subnet_1_display_name) != "" ? trimspace(var.private_subnet_1_display_name) : "${var.name_prefix}-private-mgmt",
    trimspace(var.private_subnet_2_display_name) != "" ? trimspace(var.private_subnet_2_display_name) : "${var.name_prefix}-private-hpc",
  ]

  private_dns_labels = local.consolidate_private ? ["private"] : ["mgmt", "hpc"]

  igw_name        = "${var.name_prefix}-igw"
  nat_name        = "${var.name_prefix}-nat"
  public_rt_name  = "${var.name_prefix}-public-rt"
  private_rt_name = "${var.name_prefix}-private-rt"
  public_sl_name  = "${var.name_prefix}-public-sl"
  private_sl_name = "${var.name_prefix}-private-sl"
}
