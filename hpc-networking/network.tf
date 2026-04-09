# VCN + gateways + route tables + security lists + subnets.
# Aligned with oracle-quickstart/oci-hpc network.tf: public RT → IGW; private RT → NAT + Service gateway (OSN);
# public SL: VCN + ssh_ingress_cidr for 22 (and 3000/5000 optional); private SL: VCN + same ICMP pattern as oci-hpc "internal-security-list".

resource "oci_core_virtual_network" "this" {
  compartment_id = var.compartment_ocid
  cidr_block     = var.vcn_cidr_block
  display_name   = local.vcn_name
  dns_label      = substr(local.vcn_dns_label, 0, 15)
  freeform_tags  = local.common_tags
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_ocid
  display_name   = local.igw_name
  enabled        = true
  vcn_id         = oci_core_virtual_network.this.id
  freeform_tags  = local.common_tags
}

resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_ocid
  display_name   = local.nat_name
  vcn_id         = oci_core_virtual_network.this.id
  freeform_tags  = local.common_tags
}

resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-service-gw"
  vcn_id         = oci_core_virtual_network.this.id
  freeform_tags  = local.common_tags

  services {
    service_id = local.oracle_services_network.id
  }
}

resource "oci_core_dhcp_options" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.this.id
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
  compartment_id = var.compartment_ocid
  display_name   = local.public_rt_name
  vcn_id         = oci_core_virtual_network.this.id
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  display_name   = local.private_rt_name
  vcn_id         = oci_core_virtual_network.this.id
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this.id
  }

  route_rules {
    destination       = local.oracle_services_network.cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
  }
}

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  display_name   = local.public_sl_name
  vcn_id         = oci_core_virtual_network.this.id
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
  compartment_id = var.compartment_ocid
  display_name   = local.private_sl_name
  vcn_id         = oci_core_virtual_network.this.id
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
    for_each = local.private_ssh_extra_cidrs
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
  compartment_id             = var.compartment_ocid
  display_name               = local.public_subnet_name
  vcn_id                     = oci_core_virtual_network.this.id
  cidr_block                 = local.public_subnet_cidr
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  dhcp_options_id            = oci_core_dhcp_options.this.id
  prohibit_public_ip_on_vnic = false
  dns_label                  = "public"
  freeform_tags              = local.common_tags
}

resource "oci_core_subnet" "private" {
  count                      = local.private_subnet_count
  compartment_id             = var.compartment_ocid
  display_name               = local.private_subnet_names[count.index]
  vcn_id                     = oci_core_virtual_network.this.id
  cidr_block                 = local.private_subnet_cidrs[count.index]
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  dhcp_options_id            = oci_core_dhcp_options.this.id
  prohibit_public_ip_on_vnic = true
  dns_label                  = substr(local.private_dns_labels[count.index], 0, 15)
  freeform_tags              = local.common_tags
}
