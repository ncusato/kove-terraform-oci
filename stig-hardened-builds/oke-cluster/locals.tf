locals {
  ad_name = data.oci_identity_availability_domains.ads.availability_domains[0].name
  ad_used = trimspace(var.availability_domain) != "" ? trimspace(var.availability_domain) : local.ad_name

  k8s_versions_sorted = sort(data.oci_containerengine_cluster_option.cluster.kubernetes_versions)
  k8s_version         = trimspace(var.kubernetes_version) != "" ? trimspace(var.kubernetes_version) : local.k8s_versions_sorted[length(local.k8s_versions_sorted) - 1]

  np_cluster_sources = coalesce(data.oci_containerengine_node_pool_option.node_pool_cluster.sources, [])
  np_all_sources     = coalesce(data.oci_containerengine_node_pool_option.node_pool_all.sources, [])

  node_image_sources_cluster = [
    for s in local.np_cluster_sources :
    s if try(s.source_type, "") == "IMAGE" && try(s.image_id, null) != null && try(s.image_id, "") != ""
  ]

  node_image_sources_all = [
    for s in local.np_all_sources :
    s if try(s.source_type, "") == "IMAGE" && try(s.image_id, null) != null && try(s.image_id, "") != ""
  ]

  # Prefer cluster-scoped images; subnet-scoped option can return null sources. "all" mixes arch — still filter AArch64 names for Flex x86.
  node_image_sources = length(local.node_image_sources_cluster) > 0 ? local.node_image_sources_cluster : local.node_image_sources_all

  node_image_sources_x86 = [
    for s in local.node_image_sources :
    s if !can(regex("(?i)aarch64|arm64", coalesce(try(s.source_name, ""), "")))
  ]

  # OCI OKE worker images usually include "-OKE-" in source_name; prefer those for VM.Standard.E6.Flex (avoids 400 shape/image mismatch).
  node_image_sources_oke_x86 = [
    for s in local.node_image_sources_x86 :
    s if can(regex("(?i)-oke-", coalesce(try(s.source_name, ""), "")))
  ]

  # Do not fall back to an unfiltered image (could be AArch64 and fail on E6.Flex).
  worker_image_id_effective = trimspace(var.worker_image_id) != "" ? trimspace(var.worker_image_id) : try(
    length(local.node_image_sources_oke_x86) > 0 ? local.node_image_sources_oke_x86[0].image_id : (
      length(local.node_image_sources_x86) > 0 ? local.node_image_sources_x86[0].image_id : ""
    ),
    ""
  )

  common_tags = var.tags

  oke_vcn_dns_label = substr(
    length(replace(lower(var.name_prefix), "-", "")) > 0 ? replace(lower(var.name_prefix), "-", "") : "koveoke",
    0,
    15
  )
  oracle_services_network = data.oci_core_services.oracle_services_network.services[0]
  dhcp_search_domain      = format("%s.oraclevcn.com", local.oke_vcn_dns_label)

  effective_vcn_id = var.use_existing_vcn ? var.existing_vcn_id : oci_core_virtual_network.oke[0].id

  effective_vcn_cidr = var.use_existing_vcn ? data.oci_core_vcn.existing[0].cidr_block : var.vcn_cidr_block

  public_route_table_id = var.use_existing_vcn ? var.existing_public_route_table_id : oci_core_route_table.public[0].id

  private_route_table_id = var.use_existing_vcn ? var.existing_private_route_table_id : oci_core_route_table.private[0].id

  # Dedicated OKE VCN (default 10.20.0.0/16)
  api_subnet_cidr_dedicated    = cidrsubnet(cidrsubnet(var.vcn_cidr_block, 8, 0), 4, 0)
  lb_subnet_cidr_dedicated     = cidrsubnet(var.vcn_cidr_block, 8, 1)
  worker_subnet_cidr_dedicated = cidrsubnet(var.vcn_cidr_block, 8, 2)

  # Share a /16-style VCN with rdma-platform (subnets at indices 1–3); OKE uses base, base+1, base+2
  oke_base                  = var.oke_vcn_subnet_index_base
  api_subnet_cidr_shared    = cidrsubnet(cidrsubnet(local.effective_vcn_cidr, 8, local.oke_base), 4, 0)
  lb_subnet_cidr_shared     = cidrsubnet(local.effective_vcn_cidr, 8, local.oke_base + 1)
  worker_subnet_cidr_shared = cidrsubnet(local.effective_vcn_cidr, 8, local.oke_base + 2)

  api_subnet_cidr = var.use_existing_vcn ? local.api_subnet_cidr_shared : local.api_subnet_cidr_dedicated

  lb_subnet_cidr = var.use_existing_vcn ? local.lb_subnet_cidr_shared : local.lb_subnet_cidr_dedicated

  worker_subnet_cidr = var.use_existing_vcn ? local.worker_subnet_cidr_shared : local.worker_subnet_cidr_dedicated
}
