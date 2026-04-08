resource "oci_core_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0

  lifecycle {
    precondition {
      condition     = !var.enable_bastion || local.bastion_image_id != ""
      error_message = "Could not resolve bastion image: set bastion_image_ocid or ensure Oracle Linux 8 images exist for VM.Standard.E6.Flex in this compartment."
    }
  }

  compartment_id      = var.compartment_ocid
  availability_domain = local.cluster_ad
  display_name        = local.bastion_name
  shape               = var.bastion_shape
  freeform_tags       = local.common_tags

  shape_config {
    ocpus         = var.bastion_ocpus
    memory_in_gbs = var.bastion_memory_gbs
  }

  agent_config {
    is_management_disabled = true
  }

  source_details {
    source_type = "image"
    source_id   = local.bastion_image_id
  }

  metadata = {
    ssh_authorized_keys = local.cluster_ssh_authorized_keys
    user_data           = base64encode(templatefile("${path.module}/cloud_init/bastion.yaml.tpl", {}))
  }

  create_vnic_details {
    subnet_id        = local.public_subnet_id
    assign_public_ip = true
    hostname_label   = "bastion"
  }
}

resource "oci_core_instance" "management" {
  lifecycle {
    precondition {
      condition     = local.management_image_id != ""
      error_message = "Could not resolve management VM image: set management_image_ocid or ensure Oracle Linux 8 images exist for VM.Standard.E6.Flex in this compartment."
    }

    precondition {
      condition     = trimspace(var.management_cloud_init_template_path) == "" || fileexists(var.management_cloud_init_template_path)
      error_message = "management_cloud_init_template_path must be empty or point to an existing file (use forward slashes on Windows, e.g. C:/Users/you/Downloads/cloud-init.tpl)."
    }
  }

  compartment_id      = var.compartment_ocid
  availability_domain = local.cluster_ad
  display_name        = local.management_name
  shape               = var.management_shape
  freeform_tags       = local.common_tags

  shape_config {
    ocpus         = var.management_ocpus
    memory_in_gbs = var.management_memory_gbs
  }

  agent_config {
    is_management_disabled = true
  }

  source_details {
    source_type = "image"
    source_id   = local.management_image_id
  }

  metadata = {
    ssh_authorized_keys = local.cluster_ssh_authorized_keys
    user_data           = local.management_user_data_b64
  }

  create_vnic_details {
    subnet_id        = local.management_subnet_id
    assign_public_ip = false
    hostname_label   = "mgmt"
  }
}
