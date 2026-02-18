output "created_vcn_id" {
  description = "VCN OCID (created or existing)"
  value       = local.vcn_id
}

output "head_node_public_ip" {
  description = "Public IP of the head node"
  value       = oci_core_instance.head_node.public_ip
}

output "bm_node_private_ips" {
  description = "Private IPs of BM cluster network nodes (primary VNIC)"
  value       = [for inst in data.oci_core_instance.bm_instance : inst.private_ip]
}

output "cluster_network_id" {
  description = "Cluster network OCID (RDMA)"
  value       = oci_core_cluster_network.bm_cluster.id
}

output "instance_pool_id" {
  description = "Instance pool OCID for the BM cluster"
  value       = one(oci_core_cluster_network.bm_cluster.instance_pools).id
}

# Helper: list existing VCNs in the compartment (for choosing one)
output "existing_vcns_in_compartment" {
  description = "Existing VCNs in the compartment (name -> OCID)"
  value = {
    for vcn in data.oci_core_vcns.existing_vcns.virtual_networks :
    vcn.display_name => vcn.id
  }
}
