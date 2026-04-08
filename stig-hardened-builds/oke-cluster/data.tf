data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_containerengine_cluster_option" "cluster" {
  cluster_option_id = "all"
}

data "oci_containerengine_node_pool_option" "node_pool" {
  node_pool_option_id = "all"
}
