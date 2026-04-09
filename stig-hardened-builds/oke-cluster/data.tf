data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_services" "oracle_services_network" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

data "oci_containerengine_cluster_option" "cluster" {
  cluster_option_id = "all"
}

# "all" is used as fallback when cluster-scoped options are empty (e.g. during edge cases).
data "oci_containerengine_node_pool_option" "node_pool_all" {
  compartment_id      = var.compartment_ocid
  node_pool_option_id = "all"
}

# After the cluster exists, OCI returns images compatible with that cluster (shape/arch).
data "oci_containerengine_node_pool_option" "node_pool_cluster" {
  compartment_id      = var.compartment_ocid
  node_pool_option_id = oci_containerengine_cluster.this.id
}

data "oci_core_vcn" "existing" {
  count  = var.use_existing_vcn ? 1 : 0
  vcn_id = var.existing_vcn_id
}
