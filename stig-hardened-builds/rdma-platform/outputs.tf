output "vcn_id" {
  description = "VCN OCID (created or existing)."
  value       = local.vcn_id
}

output "public_subnet_ocid" {
  description = "Public subnet (bastion)."
  value       = local.public_subnet_id
}

output "management_subnet_ocid" {
  description = "Private management subnet."
  value       = local.management_subnet_id
}

output "rdma_subnet_ocid" {
  description = "Private RDMA / BM primary VNIC subnet."
  value       = local.rdma_subnet_id
}

output "bastion_public_ip" {
  description = "Public IP when enable_bastion is true; null otherwise."
  value       = var.enable_bastion ? oci_core_instance.bastion[0].public_ip : null
}

output "management_private_ip" {
  description = "Private IP of the management VM."
  value       = oci_core_instance.management.private_ip
}

output "compute_cluster_id" {
  description = "BM compute cluster OCID."
  value       = oci_core_compute_cluster.bm_compute.id
}

output "bm_instance_ids" {
  description = "BM OCIDs in order: index 0 = control, remaining = memory nodes."
  value       = oci_core_instance.bm_nodes[*].id
}

output "bm_private_ips" {
  description = "Private IPs aligned with bm_instance_ids."
  value       = oci_core_instance.bm_nodes[*].private_ip
}

output "bm_control_private_ip" {
  description = "Private IP of the single BM control node (index 0)."
  value       = oci_core_instance.bm_nodes[0].private_ip
}

output "bm_memory_private_ips" {
  description = "Private IPs of memory nodes only (excludes control)."
  value       = slice(oci_core_instance.bm_nodes[*].private_ip, 1, length(oci_core_instance.bm_nodes))
}

output "cluster_ssh_private_key_openssh" {
  description = "Terraform-generated ED25519 private key (paired with metadata on instances). Use if your primary key is rejected by sshd."
  value       = tls_private_key.cluster_ssh.private_key_openssh
  sensitive   = true
}

output "cluster_ssh_public_key_openssh" {
  description = "Terraform-generated ED25519 public key."
  value       = tls_private_key.cluster_ssh.public_key_openssh
}

output "bm_console_vnc_connection_strings" {
  description = "Console VNC connection strings when create_bm_console_connections is true; same order as bm_instance_ids."
  value       = var.create_bm_console_connections ? oci_core_instance_console_connection.bm_console[*].vnc_connection_string : []
  sensitive   = true
}

output "oke_prerequisites" {
  description = "Subnet and compartment references for a future OKE or add-on stack (no NSGs created here)."
  value = {
    compartment_ocid       = var.compartment_ocid
    tenancy_ocid           = var.tenancy_ocid
    region                 = var.region
    vcn_id                 = local.vcn_id
    public_subnet_ocid     = local.public_subnet_id
    management_subnet_ocid = local.management_subnet_id
    rdma_subnet_ocid       = local.rdma_subnet_id
    nsg_ocids              = []
  }
}

output "existing_vcns_in_compartment" {
  description = "Existing VCNs in the compartment (display_name -> OCID)."
  value = {
    for vcn in data.oci_core_vcns.existing_vcns.virtual_networks :
    vcn.display_name => vcn.id
  }
}

output "availability_domain_used" {
  description = "AD used for bastion, management VM, compute cluster, and BMs."
  value       = local.cluster_ad
}
