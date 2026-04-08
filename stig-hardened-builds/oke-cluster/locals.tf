locals {
  ad_name = data.oci_identity_availability_domains.ads.availability_domains[0].name
  ad_used = trimspace(var.availability_domain) != "" ? trimspace(var.availability_domain) : local.ad_name

  k8s_versions_sorted = sort(data.oci_containerengine_cluster_option.cluster.kubernetes_versions)
  k8s_version         = trimspace(var.kubernetes_version) != "" ? trimspace(var.kubernetes_version) : local.k8s_versions_sorted[length(local.k8s_versions_sorted) - 1]

  # Node pool option "sources" — pick first IMAGE with an image_id (Oracle publishes OL-based node images here).
  node_image_sources = [
    for s in data.oci_containerengine_node_pool_option.node_pool.sources :
    s if try(s.source_type, "") == "IMAGE" && try(s.image_id, null) != null && try(s.image_id, "") != ""
  ]

  worker_image_id_effective = trimspace(var.worker_image_id) != "" ? trimspace(var.worker_image_id) : try(local.node_image_sources[0].image_id, "")

  common_tags = var.tags

  lb_subnet_cidr     = cidrsubnet(var.vcn_cidr_block, 8, 1)
  worker_subnet_cidr = cidrsubnet(var.vcn_cidr_block, 8, 2)
  # Kubernetes API endpoint subnet (/28 inside 10.20.0.0/24)
  api_subnet_cidr = cidrsubnet(cidrsubnet(var.vcn_cidr_block, 8, 0), 4, 0)
}
