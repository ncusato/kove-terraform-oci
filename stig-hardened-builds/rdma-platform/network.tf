resource "oci_core_virtual_network" "this" {
  count          = var.use_existing_vcn ? 0 : 1
  cidr_block     = var.vcn_cidr_block
  compartment_id = var.compartment_ocid
  display_name   = local.vcn_name
  dns_label      = substr(local.vcn_dns_label, 0, 15)
  freeform_tags  = local.common_tags
}

resource "oci_core_internet_gateway" "this" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = local.igw_name
  enabled        = true
  vcn_id         = oci_core_virtual_network.this[0].id
  freeform_tags  = local.common_tags
}

resource "oci_core_nat_gateway" "this" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = local.nat_name
  vcn_id         = oci_core_virtual_network.this[0].id
  freeform_tags  = local.common_tags
}

resource "oci_core_service_gateway" "this" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-service-gw"
  vcn_id         = oci_core_virtual_network.this[0].id
  freeform_tags  = local.common_tags

  services {
    service_id = local.oracle_services_network.id
  }
}

resource "oci_core_dhcp_options" "this" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.this[0].id
  display_name   = "${var.name_prefix}-dhcp"
  freeform_tags  = local.common_tags

  options {
    type        = "DomainNameServer"
    server_type = "VcnLocalPlusInternet"
  }

  options {
    type                = "SearchDomain"
    search_domain_names = [local.dhcp_search_domain]
  }
}

resource "oci_core_route_table" "public" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = local.public_rt_name
  vcn_id         = oci_core_virtual_network.this[0].id
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this[0].id
  }
}

resource "oci_core_route_table" "private" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = local.private_rt_name
  vcn_id         = oci_core_virtual_network.this[0].id
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this[0].id
  }
}

resource "oci_core_security_list" "public" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = local.public_sl_name
  vcn_id         = oci_core_virtual_network.this[0].id
  freeform_tags  = local.common_tags

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr_block
  }

  ingress_security_rules {
    protocol = "6"
    source   = var.ssh_ingress_cidr
    tcp_options {
      min = 22
      max = 22
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.public_ingress_hpc_ui_ports ? [3000, 5000] : []
    content {
      protocol = "6"
      source   = var.ssh_ingress_cidr
      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }

  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol = "1"
    source   = var.vcn_cidr_block
    icmp_options {
      type = 3
    }
  }
}

resource "oci_core_security_list" "private" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = local.private_sl_name
  vcn_id         = oci_core_virtual_network.this[0].id
  freeform_tags  = local.common_tags

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr_block
  }

  dynamic "ingress_security_rules" {
    for_each = local.private_subnet_ssh_extra_cidrs
    content {
      protocol = "6"
      source   = ingress_security_rules.value
      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol = "1"
    source   = var.vcn_cidr_block
    icmp_options {
      type = 3
    }
  }
}

resource "oci_core_subnet" "public" {
  count                      = var.use_existing_vcn ? 0 : 1
  compartment_id             = var.compartment_ocid
  display_name               = local.public_subnet_name
  vcn_id                     = oci_core_virtual_network.this[0].id
  cidr_block                 = local.public_subnet_cidr
  route_table_id             = oci_core_route_table.public[0].id
  security_list_ids          = [oci_core_security_list.public[0].id]
  prohibit_public_ip_on_vnic = false
  dns_label                  = "public"
  freeform_tags              = local.common_tags
}

resource "oci_core_subnet" "management" {
  count                      = var.use_existing_vcn ? 0 : 1
  compartment_id             = var.compartment_ocid
  display_name               = local.mgmt_subnet_name
  vcn_id                     = oci_core_virtual_network.this[0].id
  cidr_block                 = local.mgmt_subnet_cidr
  route_table_id             = oci_core_route_table.private[0].id
  security_list_ids          = [oci_core_security_list.private[0].id]
  dhcp_options_id            = oci_core_dhcp_options.this[0].id
  prohibit_public_ip_on_vnic = true
  dns_label                  = "mgmt"
  freeform_tags              = local.common_tags
}

resource "oci_core_subnet" "rdma" {
  count                      = var.use_existing_vcn ? 0 : 1
  compartment_id             = var.compartment_ocid
  display_name               = local.rdma_subnet_name
  vcn_id                     = oci_core_virtual_network.this[0].id
  cidr_block                 = local.rdma_subnet_cidr
  route_table_id             = oci_core_route_table.private[0].id
  security_list_ids          = [oci_core_security_list.private[0].id]
  dhcp_options_id            = oci_core_dhcp_options.this[0].id
  prohibit_public_ip_on_vnic = true
  dns_label                  = "rdma"
  freeform_tags              = local.common_tags
}
