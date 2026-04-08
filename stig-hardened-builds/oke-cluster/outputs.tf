output "cluster_id" {
  description = "OKE cluster OCID"
  value       = oci_containerengine_cluster.this.id
}

output "cluster_kubernetes_version" {
  description = "Kubernetes version running on the cluster"
  value       = oci_containerengine_cluster.this.kubernetes_version
}

output "node_pool_id" {
  description = "Worker node pool OCID"
  value       = oci_containerengine_node_pool.workers.id
}

output "vcn_id" {
  value = oci_core_virtual_network.oke.id
}

output "kubeconfig_hint" {
  description = "Merge kubeconfig via OCI CLI (install oci-cli, then run)"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.this.id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0 --kube-endpoint ${var.public_control_plane_endpoint ? "PUBLIC_ENDPOINT" : "PRIVATE_ENDPOINT"}"
}

output "kubernetes_endpoint" {
  description = "Public or private Kubernetes API hostname (from OCI after cluster is ACTIVE)"
  value       = oci_containerengine_cluster.this.endpoints[0].kubernetes
}
