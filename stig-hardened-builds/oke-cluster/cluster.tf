resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = local.k8s_version
  name               = "${var.name_prefix}-cluster"
  vcn_id             = oci_core_virtual_network.oke.id
  freeform_tags      = local.common_tags

  cluster_pod_network_options {
    cni_type = "FLANNEL_OVERLAY"
  }

  endpoint_config {
    is_public_ip_enabled = var.public_control_plane_endpoint
    subnet_id            = oci_core_subnet.api.id
    nsg_ids              = []
  }

  options {
    service_lb_subnet_ids = [oci_core_subnet.lb.id]

    kubernetes_network_config {
      pods_cidr     = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
  }

  lifecycle {
    precondition {
      condition     = local.worker_image_id_effective != ""
      error_message = "No worker node image resolved: set worker_image_id or ensure node pool option sources include an IMAGE with image_id for this region."
    }
  }
}

resource "oci_containerengine_node_pool" "workers" {
  cluster_id         = oci_containerengine_cluster.this.id
  compartment_id     = var.compartment_ocid
  kubernetes_version = local.k8s_version
  name               = "${var.name_prefix}-workers"
  node_shape         = var.node_pool_shape
  freeform_tags      = local.common_tags

  dynamic "node_shape_config" {
    for_each = can(regex("Flex$", var.node_pool_shape)) ? [1] : []
    content {
      ocpus         = var.node_pool_ocpus
      memory_in_gbs = var.node_pool_memory_gbs
    }
  }

  node_source_details {
    image_id    = local.worker_image_id_effective
    source_type = "IMAGE"
  }

  node_config_details {
    placement_configs {
      availability_domain = local.ad_used
      subnet_id           = oci_core_subnet.workers.id
    }
    size = var.node_pool_size
  }

  ssh_public_key = trimspace(replace(var.ssh_public_key, "\r", ""))
}
