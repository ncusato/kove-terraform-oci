terraform {
  required_version = ">= 1.3.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Terraform-generated SSH key for head->BM (oci-hpc pattern). ED25519 keeps user_data smaller.
resource "tls_private_key" "cluster_ssh" {
  algorithm = "ED25519"
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  region       = var.region
  # Resource Manager uses resource principal; no API key needed.
}

# -------------------------------------------------------------------
# Data sources
# -------------------------------------------------------------------

# Availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# When using an existing private subnet, read its AD so placement matches (wrong AD → 0 instances launched).
data "oci_core_subnet" "existing_private" {
  count     = var.use_existing_vcn ? 1 : 0
  subnet_id = var.existing_private_subnet_id
}

locals {
  # Use the first AD by default
  ad_name = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

# Optional helper: list existing VCNs & Subnets in the compartment
# (useful when you want to plug in existing IDs)
data "oci_core_vcns" "existing_vcns" {
  compartment_id = var.compartment_ocid
}

# Latest Oracle Linux 8 image for head node (used when head_node_image_ocid is empty)
data "oci_core_images" "ol8_head" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.E6.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# -------------------------------------------------------------------
# Networking (optional create vs existing)
# -------------------------------------------------------------------

# Create VCN only when use_existing_vcn = false
resource "oci_core_virtual_network" "this" {
  count          = var.use_existing_vcn ? 0 : 1
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "cluster-vcn"
  dns_label      = "clustervcn"
}

resource "oci_core_internet_gateway" "this" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "cluster-igw"
  enabled        = true
  vcn_id         = oci_core_virtual_network.this[0].id
}

resource "oci_core_nat_gateway" "this" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "cluster-nat"
  vcn_id         = oci_core_virtual_network.this[0].id
}

resource "oci_core_route_table" "public" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "cluster-public-rt"
  vcn_id         = oci_core_virtual_network.this[0].id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this[0].id
  }
}

resource "oci_core_route_table" "private" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "cluster-private-rt"
  vcn_id         = oci_core_virtual_network.this[0].id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this[0].id
  }
}

# Security list for public subnet: SSH from internet (adjust as needed)
resource "oci_core_security_list" "public" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "cluster-public-sl"
  vcn_id         = oci_core_virtual_network.this[0].id

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Allow ICMP (ping) from anywhere (optional)
  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"

    icmp_options {
      type = 8
      code = 0
    }
  }
}

# Security list for private subnet: only intra-VCN (and you can add more)
resource "oci_core_security_list" "private" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "cluster-private-sl"
  vcn_id         = oci_core_virtual_network.this[0].id

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/16"
  }
}

# Public subnet (for head node)
resource "oci_core_subnet" "public" {
  count                      = var.use_existing_vcn ? 0 : 1
  compartment_id             = var.compartment_ocid
  display_name               = "cluster-public-subnet"
  vcn_id                     = oci_core_virtual_network.this[0].id
  cidr_block                 = "10.0.1.0/24"
  route_table_id             = oci_core_route_table.public[0].id
  security_list_ids          = [oci_core_security_list.public[0].id]
  prohibit_public_ip_on_vnic = false
  dns_label                  = "publicsub"
}

# Private subnet (for BM nodes / cluster network primary VNIC)
resource "oci_core_subnet" "private" {
  count                      = var.use_existing_vcn ? 0 : 1
  compartment_id             = var.compartment_ocid
  display_name               = "cluster-private-subnet"
  vcn_id                     = oci_core_virtual_network.this[0].id
  cidr_block                 = "10.0.2.0/24"
  route_table_id             = oci_core_route_table.private[0].id
  security_list_ids          = [oci_core_security_list.private[0].id]
  prohibit_public_ip_on_vnic = true
  dns_label                  = "privatesub"
}

# Locals to abstract between new vs existing networking
locals {
  vcn_id            = var.use_existing_vcn ? var.existing_vcn_id : oci_core_virtual_network.this[0].id
  public_subnet_id  = var.use_existing_vcn ? var.existing_public_subnet_id : oci_core_subnet.public[0].id
  private_subnet_id = var.use_existing_vcn ? var.existing_private_subnet_id : oci_core_subnet.private[0].id
  # AD-specific subnet launches must use the subnet's AD or instance pool creation can stay at 0/N.
  private_subnet_ad = var.use_existing_vcn ? try(trimspace(data.oci_core_subnet.existing_private[0].availability_domain), "") : try(trimspace(oci_core_subnet.private[0].availability_domain), "")
  # Same as oci-hpc `ad`: explicit override, else subnet AD if available, else first tenancy AD.
  cluster_network_ad = length(trimspace(var.cluster_network_availability_domain)) > 0 ? var.cluster_network_availability_domain : (
    length(local.private_subnet_ad) > 0 ? local.private_subnet_ad : local.ad_name
  )

  # BM instance create (compute cluster path); same knob as former cluster-network wait.
  bm_instance_create_timeout = trimspace(var.cluster_network_create_timeout) != "" ? var.cluster_network_create_timeout : "2h"

  # OCI rejects keys with stray CR (common when ssh_public_key is pasted from Windows); never emit empty lines.
  cluster_ssh_authorized_keys = join("\n", compact([
    trimspace(replace(var.ssh_public_key, "\r", "")),
    chomp(trimspace(replace(tls_private_key.cluster_ssh.public_key_openssh, "\r", ""))),
  ]))
}

# Single zip of playbooks to stay under OCI metadata limit (32KB). Only used when run_ansible_from_head = true.
# Exclude site.yml (unused oci-hpc-style mega-playbook) — it pushes user_data over the limit when embedded.
data "archive_file" "playbooks" {
  count       = var.run_ansible_from_head ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/playbooks"
  output_path = "${path.module}/.terraform/playbooks.zip"
  excludes    = ["site.yml"]
}

# Bootstrap script inputs (only used when run_ansible_from_head = true)
locals {
  extra_vars_yaml       = <<-EOT
rhsm_username: ${jsonencode(var.rhsm_username)}
rhsm_password: ${jsonencode(var.rhsm_password)}
rdma_ping_target: ${jsonencode(var.rdma_ping_target)}
cluster_ssh_user: ${jsonencode(var.instance_ssh_user)}
EOT
  bm_private_ips_csv    = var.run_ansible_from_head ? join(",", compact(oci_core_instance.bm_compute_nodes[*].private_ip)) : ""
  bm_instance_ocids_csv = var.run_ansible_from_head ? join(",", oci_core_instance.bm_compute_nodes[*].id) : ""
  bootstrap_template_vars = var.run_ansible_from_head ? {
    compartment_id        = var.compartment_ocid
    region                = var.region
    tenancy_ocid          = var.tenancy_ocid
    bm_count              = var.bm_node_count
    instance_ssh_user     = var.instance_ssh_user
    head_node_ssh_user    = var.head_node_ssh_user != "" ? var.head_node_ssh_user : "opc"
    payload_b64           = filebase64(data.archive_file.playbooks[0].output_path)
    extra_vars_b64        = base64encode(local.extra_vars_yaml)
    rhsm_username_b64     = base64encode(var.rhsm_username)
    rhsm_password_b64     = base64encode(var.rhsm_password)
    bm_private_ips_csv    = local.bm_private_ips_csv
    bm_instance_ocids_csv = local.bm_instance_ocids_csv
    ssh_private_key_b64   = base64encode(tls_private_key.cluster_ssh.private_key_openssh)
  } : {}
}

# -------------------------------------------------------------------
# Head node (VM.Standard.E6.Flex)
# -------------------------------------------------------------------

resource "oci_core_instance" "head_node" {
  compartment_id      = var.compartment_ocid
  availability_domain = local.ad_name
  # After BM nodes exist (Ansible bootstrap needs OCIDs / private IPs in user_data).
  depends_on = [time_sleep.wait_bm_instances]

  display_name = "${var.cluster_display_name_prefix}-head-node"
  shape        = "VM.Standard.E6.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 8
  }

  agent_config {
    is_management_disabled = true
  }

  source_details {
    source_type = "image"
    # When head_node_image_ocid is empty, use latest OL8 so head doesn't need RHSM; Ansible registers RHEL on BM only.
    source_id = var.head_node_image_ocid != "" ? var.head_node_image_ocid : (length(data.oci_core_images.ol8_head.images) > 0 ? data.oci_core_images.ol8_head.images[0].id : var.bm_node_image_ocid)
  }

  create_vnic_details {
    subnet_id        = local.public_subnet_id
    assign_public_ip = true
    hostname_label   = "headnode"
  }

  # Match oci-hpc: user key first, then generated key (see local.cluster_ssh_authorized_keys).
  metadata = merge(
    { ssh_authorized_keys = local.cluster_ssh_authorized_keys },
    var.run_ansible_from_head ? { user_data = base64encode(templatefile("${path.module}/scripts/cloud_init_bootstrap.yaml.tpl", { bootstrap_script_b64 = base64encode(templatefile("${path.module}/scripts/head_bootstrap.sh.tpl", local.bootstrap_template_vars)) })) } : {}
  )
}

# -------------------------------------------------------------------
# BM nodes via compute cluster (oracle-quickstart/oci-hpc compute-cluster.tf + compute-nodes.tf)
# Avoids cluster network + instance pool "Create instances in pool" path.
# -------------------------------------------------------------------

resource "oci_core_compute_cluster" "bm_compute" {
  lifecycle {
    precondition {
      condition = !var.use_existing_vcn || (
        length(trimspace(var.existing_vcn_id)) > 0 &&
        length(trimspace(var.existing_public_subnet_id)) > 0 &&
        length(trimspace(var.existing_private_subnet_id)) > 0
      )
      error_message = "When use_existing_vcn is true, set existing_vcn_id, existing_public_subnet_id, and existing_private_subnet_id (non-empty)."
    }
  }

  availability_domain = local.cluster_network_ad
  compartment_id      = var.compartment_ocid
  display_name        = "${var.cluster_display_name_prefix}-compute-cluster"
}

resource "oci_core_instance" "bm_compute_nodes" {
  count      = var.bm_node_count
  depends_on = [oci_core_compute_cluster.bm_compute]

  availability_domain = local.cluster_network_ad
  compartment_id      = var.compartment_ocid
  display_name        = "${var.cluster_display_name_prefix}-bm-${count.index + 1}"
  shape               = var.bm_node_shape

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

  metadata = {
    ssh_authorized_keys = local.cluster_ssh_authorized_keys
  }

  source_details {
    source_type             = "image"
    source_id               = var.bm_node_image_ocid
    boot_volume_size_in_gbs = var.bm_boot_volume_size_gbs
    boot_volume_vpus_per_gb = 30
  }

  compute_cluster_id = oci_core_compute_cluster.bm_compute.id

  create_vnic_details {
    subnet_id        = local.private_subnet_id
    assign_public_ip = false
  }

  timeouts {
    create = local.bm_instance_create_timeout
    update = "30m"
    delete = "30m"
  }
}

resource "time_sleep" "wait_bm_instances" {
  create_duration = var.run_ansible_from_head ? var.bm_pool_ready_wait : "0s"
  depends_on      = [oci_core_instance.bm_compute_nodes]
}
