locals {
  ad_name = data.oci_identity_availability_domains.ads.availability_domains[0].name

  private_subnet_ssh_extra_cidrs = compact([for s in split(",", var.private_subnet_ssh_sources_extras) : trimspace(s) if trimspace(s) != ""])

  public_subnet_cidr = cidrsubnet(var.vcn_cidr_block, 8, 1)
  mgmt_subnet_cidr   = cidrsubnet(var.vcn_cidr_block, 8, 2)
  rdma_subnet_cidr   = cidrsubnet(var.vcn_cidr_block, 8, 3)
  dns_safe_prefix    = substr(replace(replace(lower(trimspace(var.name_prefix)), "-", ""), "_", ""), 0, 12)
  vcn_dns_label      = length(local.dns_safe_prefix) > 0 ? local.dns_safe_prefix : "rdmaplatform"

  vcn_name             = "${var.name_prefix}-vcn"
  igw_name             = "${var.name_prefix}-igw"
  nat_name             = "${var.name_prefix}-nat"
  public_rt_name       = "${var.name_prefix}-public-rt"
  private_rt_name      = "${var.name_prefix}-private-rt"
  public_sl_name       = "${var.name_prefix}-public-sl"
  private_sl_name      = "${var.name_prefix}-private-sl"
  public_subnet_name   = "${var.name_prefix}-public"
  mgmt_subnet_name     = "${var.name_prefix}-mgmt"
  rdma_subnet_name     = "${var.name_prefix}-rdma"
  bastion_name         = "${var.name_prefix}-bastion"
  management_name      = "${var.name_prefix}-management"
  compute_cluster_name = "${var.name_prefix}-compute-cluster"
  bm_name_prefix       = "${var.name_prefix}-bm"

  vcn_id = var.use_existing_vcn ? var.existing_vcn_id : oci_core_virtual_network.this[0].id

  public_subnet_id     = var.use_existing_vcn ? var.existing_public_subnet_id : oci_core_subnet.public[0].id
  management_subnet_id = var.use_existing_vcn ? var.existing_management_subnet_id : oci_core_subnet.management[0].id
  rdma_subnet_id       = var.use_existing_vcn ? var.existing_rdma_subnet_id : oci_core_subnet.rdma[0].id

  rdma_subnet_ad   = var.use_existing_vcn ? try(trimspace(data.oci_core_subnet.existing_rdma[0].availability_domain), "") : try(trimspace(oci_core_subnet.rdma[0].availability_domain), "")
  mgmt_subnet_ad   = var.use_existing_vcn ? try(trimspace(data.oci_core_subnet.existing_management[0].availability_domain), "") : try(trimspace(oci_core_subnet.management[0].availability_domain), "")
  public_subnet_ad = var.use_existing_vcn ? try(trimspace(data.oci_core_subnet.existing_public[0].availability_domain), "") : try(trimspace(oci_core_subnet.public[0].availability_domain), "")

  stack_ad = trimspace(var.availability_domain)

  cluster_ad = length(local.stack_ad) > 0 ? local.stack_ad : (
    length(local.rdma_subnet_ad) > 0 ? local.rdma_subnet_ad : (
      length(local.mgmt_subnet_ad) > 0 ? local.mgmt_subnet_ad : (
        length(local.public_subnet_ad) > 0 ? local.public_subnet_ad : local.ad_name
      )
    )
  )

  bm_instance_create_timeout = trimspace(var.cluster_network_create_timeout) != "" ? var.cluster_network_create_timeout : "2h"

  cluster_ssh_authorized_keys = join("\n", compact([
    trimspace(replace(var.ssh_public_key, "\r", "")),
    chomp(trimspace(replace(tls_private_key.cluster_ssh.public_key_openssh, "\r", ""))),
  ]))

  bm_script_path = "${path.module}/../../scripts/bm_imds_ssh_bootstrap.sh"

  bm_user_data_b64 = var.bm_imds_ssh_key_bootstrap ? base64encode(replace(replace(templatefile(local.bm_script_path, {
    stack_ssh_authorized_keys_b64 = base64encode(local.cluster_ssh_authorized_keys)
  }), "\r\n", "\n"), "\r", "\n")) : ""

  bm_total_count = 1 + var.memory_node_count

  ol8_image_id = length(data.oci_core_images.ol8_flex.images) > 0 ? data.oci_core_images.ol8_flex.images[0].id : ""

  bastion_image_id    = trimspace(var.bastion_image_ocid) != "" ? var.bastion_image_ocid : local.ol8_image_id
  management_image_id = trimspace(var.management_image_ocid) != "" ? var.management_image_ocid : local.ol8_image_id

  common_tags = var.tags

  # Management cloud-init: default stub in-repo, or your file (e.g. under Downloads) via management_cloud_init_template_path.
  management_cloud_init_src_path = trimspace(var.management_cloud_init_template_path) != "" ? var.management_cloud_init_template_path : "${path.module}/cloud_init/kove-rdma-cloud-init-standalone-runtime.txt"

  management_cloud_init_vars = merge(
    {
      rhsm_org_id         = var.rhsm_org_id
      rhsm_activation_key = var.rhsm_activation_key
      playbooks_zip_url   = var.playbooks_zip_url
    },
    var.cloud_init_template_extra_vars,
  )

  management_user_data_rendered = replace(replace(
    templatefile(local.management_cloud_init_src_path, local.management_cloud_init_vars),
    "\r\n", "\n"),
  "\r", "\n")

  management_user_data_b64 = base64encode(local.management_user_data_rendered)
}
