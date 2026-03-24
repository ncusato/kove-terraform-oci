output "created_vcn_id" {
  description = "VCN OCID (created or existing)"
  value       = local.vcn_id
}

output "head_node_public_ip" {
  description = "Public IP of the head node"
  value       = oci_core_instance.head_node.public_ip
}

# Same ED25519 private key Ansible/bootstrap installs on the head for BM access; also in metadata as second authorized_key.
output "cluster_ssh_private_key_openssh" {
  description = "If ssh opc@head rejects your RSA key (OpenSSH 9+): save to a file, chmod 600, then ssh -i thatfile opc@<head_node_public_ip>"
  value         = tls_private_key.cluster_ssh.private_key_openssh
  sensitive     = true
}

output "bm_node_private_ips" {
  description = "Private IPs of BM compute-cluster nodes (same order as bm_instance_ids)."
  value       = oci_core_instance.bm_compute_nodes[*].private_ip
}

output "bm_instance_ids" {
  description = "OCIDs of BM instances attached to the compute cluster."
  value       = oci_core_instance.bm_compute_nodes[*].id
}

output "compute_cluster_id" {
  description = "Compute cluster OCID (BM nodes are oci_core_instance with compute_cluster_id set)."
  value       = oci_core_compute_cluster.bm_compute.id
}

# Helper: list existing VCNs in the compartment (for choosing one)
output "existing_vcns_in_compartment" {
  description = "Existing VCNs in the compartment (name -> OCID)"
  value = {
    for vcn in data.oci_core_vcns.existing_vcns.virtual_networks :
    vcn.display_name => vcn.id
  }
}
