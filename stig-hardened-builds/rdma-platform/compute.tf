resource "oci_core_compute_cluster" "bm_compute" {
  lifecycle {
    precondition {
      condition = !var.use_existing_vcn || (
        length(trimspace(var.existing_vcn_id)) > 0 &&
        length(trimspace(var.existing_public_subnet_id)) > 0 &&
        length(trimspace(var.existing_management_subnet_id)) > 0 &&
        length(trimspace(var.existing_rdma_subnet_id)) > 0
      )
      error_message = "When use_existing_vcn is true, set existing_vcn_id, existing_public_subnet_id, existing_management_subnet_id, and existing_rdma_subnet_id (non-empty)."
    }
  }

  availability_domain = local.cluster_ad
  compartment_id      = var.compartment_ocid
  display_name        = local.compute_cluster_name
  freeform_tags       = local.common_tags
}

resource "oci_core_instance" "bm_nodes" {
  count      = local.bm_total_count
  depends_on = [oci_core_compute_cluster.bm_compute]

  availability_domain = local.cluster_ad
  compartment_id      = var.compartment_ocid
  display_name        = count.index == 0 ? "${local.bm_name_prefix}-control" : "${local.bm_name_prefix}-mem-${count.index}"
  shape               = var.bm_node_shape
  freeform_tags       = local.common_tags

  capacity_reservation_id = trimspace(var.bm_capacity_reservation_id) != "" ? var.bm_capacity_reservation_id : null

  dynamic "platform_config" {
    for_each = var.bm_generic_platform_config ? [1] : []
    content {
      type                                           = "GENERIC_BM"
      is_symmetric_multi_threading_enabled           = var.bm_smt_enabled
      is_access_control_service_enabled              = false
      is_input_output_memory_management_unit_enabled = false
      are_virtual_instructions_enabled               = false
      numa_nodes_per_socket                          = var.bm_numa_nodes_per_socket
      percentage_of_cores_enabled                    = 100
    }
  }

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = true
    is_monitoring_disabled   = false
    plugins_config {
      name          = "OS Management Service Agent"
      desired_state = "DISABLED"
    }
    dynamic "plugins_config" {
      for_each = var.use_compute_agent ? ["ENABLED"] : ["DISABLED"]
      content {
        name          = "Compute HPC RDMA Authentication"
        desired_state = plugins_config.value
      }
    }
    dynamic "plugins_config" {
      for_each = var.use_compute_agent ? ["ENABLED"] : ["DISABLED"]
      content {
        name          = "Compute HPC RDMA Auto-Configuration"
        desired_state = plugins_config.value
      }
    }
  }

  metadata = merge(
    { ssh_authorized_keys = local.cluster_ssh_authorized_keys },
    local.bm_user_data_b64 != "" ? { user_data = local.bm_user_data_b64 } : {}
  )

  source_details {
    source_type             = "image"
    source_id               = var.bm_node_image_ocid
    boot_volume_size_in_gbs = var.bm_boot_volume_size_gbs
    boot_volume_vpus_per_gb = 30
  }

  compute_cluster_id = oci_core_compute_cluster.bm_compute.id

  create_vnic_details {
    subnet_id        = local.rdma_subnet_id
    assign_public_ip = false
    hostname_label   = count.index == 0 ? "rdmactrl" : "rdmamem${count.index}"
  }

  timeouts {
    create = local.bm_instance_create_timeout
    update = "30m"
    delete = "30m"
  }
}

resource "oci_core_instance_console_connection" "bm_console" {
  count = var.create_bm_console_connections ? local.bm_total_count : 0

  instance_id = oci_core_instance.bm_nodes[count.index].id
  public_key  = trimspace(var.ssh_public_key)
}
