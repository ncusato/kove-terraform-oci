resource "oci_core_virtual_network" "oke" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  cidr_block     = var.vcn_cidr_block
  display_name   = "${var.name_prefix}-vcn"
  dns_label      = substr(replace(lower(var.name_prefix), "-", ""), 0, 15)
  freeform_tags  = local.common_tags
}

resource "oci_core_internet_gateway" "oke" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-igw"
  enabled        = true
  vcn_id         = oci_core_virtual_network.oke[0].id
  freeform_tags  = local.common_tags
}

resource "oci_core_nat_gateway" "oke" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-nat"
  vcn_id         = oci_core_virtual_network.oke[0].id
  freeform_tags  = local.common_tags
}

resource "oci_core_service_gateway" "oke" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-service-gw"
  vcn_id         = oci_core_virtual_network.oke[0].id
  freeform_tags  = local.common_tags

  services {
    service_id = local.oracle_services_network.id
  }
}

resource "oci_core_dhcp_options" "oke" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.oke[0].id
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
  display_name   = "${var.name_prefix}-public-rt"
  vcn_id         = oci_core_virtual_network.oke[0].id
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.oke[0].id
  }
}

resource "oci_core_route_table" "private" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-private-rt"
  vcn_id         = oci_core_virtual_network.oke[0].id
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.oke[0].id
  }

  route_rules {
    destination       = local.oracle_services_network.cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.oke[0].id
  }
}

resource "oci_core_security_list" "api" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-api-sl"
  vcn_id         = local.effective_vcn_id
  freeform_tags  = local.common_tags

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 12250
      max = 12250
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
}

resource "oci_core_security_list" "lb" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-lb-sl"
  vcn_id         = local.effective_vcn_id
  freeform_tags  = local.common_tags

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "all"
    source   = local.effective_vcn_cidr
  }

  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_security_list" "workers" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-worker-sl"
  vcn_id         = local.effective_vcn_id
  freeform_tags  = local.common_tags

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "all"
    source   = local.effective_vcn_cidr
  }

  ingress_security_rules {
    protocol = "6"
    source   = var.worker_ssh_ingress_cidr
    tcp_options {
      min = 22
      max = 22
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
}

resource "oci_core_subnet" "api" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = local.effective_vcn_id
  cidr_block                 = local.api_subnet_cidr
  display_name               = "${var.name_prefix}-k8s-api"
  dns_label                  = "k8sapi"
  route_table_id             = local.public_route_table_id
  security_list_ids          = [oci_core_security_list.api.id]
  dhcp_options_id            = length(oci_core_dhcp_options.oke) > 0 ? oci_core_dhcp_options.oke[0].id : null
  prohibit_public_ip_on_vnic = false
  freeform_tags              = local.common_tags
}

resource "oci_core_subnet" "lb" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = local.effective_vcn_id
  cidr_block                 = local.lb_subnet_cidr
  display_name               = "${var.name_prefix}-svc-lb"
  dns_label                  = "svclb"
  route_table_id             = local.public_route_table_id
  security_list_ids          = [oci_core_security_list.lb.id]
  dhcp_options_id            = length(oci_core_dhcp_options.oke) > 0 ? oci_core_dhcp_options.oke[0].id : null
  prohibit_public_ip_on_vnic = false
  freeform_tags              = local.common_tags
}

resource "oci_core_subnet" "workers" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = local.effective_vcn_id
  cidr_block                 = local.worker_subnet_cidr
  display_name               = "${var.name_prefix}-workers"
  dns_label                  = "k8swrkr"
  route_table_id             = local.private_route_table_id
  security_list_ids          = [oci_core_security_list.workers.id]
  dhcp_options_id            = length(oci_core_dhcp_options.oke) > 0 ? oci_core_dhcp_options.oke[0].id : null
  prohibit_public_ip_on_vnic = true
  freeform_tags              = local.common_tags
}
