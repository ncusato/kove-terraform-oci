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
  description = "VCN hosting the cluster (dedicated OKE VCN or shared rdma VCN)."
  value       = local.effective_vcn_id
}

output "kubeconfig_hint" {
  description = "Merge kubeconfig via OCI CLI (install oci-cli, then run)"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.this.id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0 --kube-endpoint ${var.public_control_plane_endpoint ? "PUBLIC_ENDPOINT" : "PRIVATE_ENDPOINT"}"
}

output "kubernetes_endpoint" {
  description = "Public or private Kubernetes API hostname (from OCI after cluster is ACTIVE)"
  value       = oci_containerengine_cluster.this.endpoints[0].kubernetes
}

output "worker_node_image_ocid" {
  description = "Image OCID used for worker nodes (set worker_image_id to override auto-selection)."
  value       = local.worker_image_id_effective
}

output "networking_layout" {
  description = "Explains subnet count: dedicated OKE VCN = 3 subnets; shared RDMA VCN = 3 RDMA + 3 OKE = 6 subnets in one VCN."
  value = var.use_existing_vcn ? "Shared VCN: RDMA subnets at indices 1–3 under the VCN /16; OKE subnets at base ${var.oke_vcn_subnet_index_base}–${var.oke_vcn_subnet_index_base + 2} (default 4–6). Six subnets total in the VCN is expected." : "Dedicated OKE VCN: three subnets only (API, LB, workers) created by this stack."
}
