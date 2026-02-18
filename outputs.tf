output "created_vcn_id" {
  description = "VCN OCID (created or existing)"
  value       = local.vcn_id
}

output "head_node_public_ip" {
  description = "Public IP of the head node"
  value       = oci_core_instance.head_node.public_ip
}

output "bm_node_private_ips" {
  description = "Private IPs of BM cluster nodes"
  value       = [
    for i in oci_core_instance.bm_nodes :
    i.private_ip
  ]
}

# Helper: list existing VCNs in the compartment (for choosing one)
output "existing_vcns_in_compartment" {
  description = "Existing VCNs in the compartment (name -> OCID)"
  value = {
    for vcn in data.oci_core_vcns.existing_vcns.virtual_networks :
    vcn.display_name => vcn.id
  }
}
