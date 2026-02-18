terraform {
  required_version = ">= 1.3.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# -------------------------------------------------------------------
# Data sources
# -------------------------------------------------------------------

# Availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
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

# Private subnet (for BM nodes)
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
  vcn_id = var.use_existing_vcn
    ? var.existing_vcn_id
    : oci_core_virtual_network.this[0].id

  public_subnet_id = var.use_existing_vcn
    ? var.existing_public_subnet_id
    : oci_core_subnet.public[0].id

  private_subnet_id = var.use_existing_vcn
    ? var.existing_private_subnet_id
    : oci_core_subnet.private[0].id
}

# -------------------------------------------------------------------
# Head node (VM.Standard.E6.Flex)
# -------------------------------------------------------------------

resource "oci_core_instance" "head_node" {
  compartment_id = var.compartment_ocid
  availability_domain = local.ad_name

  display_name = "head-node"
  shape        = "VM.Standard.E6.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 8
  }

  source_details {
    source_type = "image"
    # Reuse the RHEL 8.8 BM image OCID for head node to simplify stack inputs.
    source_id   = var.bm_node_image_ocid
  }

  create_vnic_details {
    subnet_id        = local.public_subnet_id
    assign_public_ip = true
    hostname_label   = "headnode"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

# -------------------------------------------------------------------
# 4-node BM.Optimized3.36 cluster (private subnet)
# -------------------------------------------------------------------

resource "oci_core_instance" "bm_nodes" {
  count               = 4
  compartment_id      = var.compartment_ocid
  availability_domain = local.ad_name

  display_name = "bm-node-${count.index}"
  shape        = "BM.Optimized3.36"

  source_details {
    source_type = "image"
    source_id   = var.bm_node_image_ocid
  }

  create_vnic_details {
    subnet_id        = local.private_subnet_id
    assign_public_ip = false
    hostname_label   = "bmnode${count.index}"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}
