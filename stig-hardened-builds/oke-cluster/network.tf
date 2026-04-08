resource "oci_core_virtual_network" "oke" {
  compartment_id = var.compartment_ocid
  cidr_block     = var.vcn_cidr_block
  display_name   = "${var.name_prefix}-vcn"
  dns_label      = substr(replace(lower(var.name_prefix), "-", ""), 0, 15)
  freeform_tags  = local.common_tags
}

resource "oci_core_internet_gateway" "oke" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-igw"
  enabled        = true
  vcn_id         = oci_core_virtual_network.oke.id
  freeform_tags  = local.common_tags
}

resource "oci_core_nat_gateway" "oke" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-nat"
  vcn_id         = oci_core_virtual_network.oke.id
  freeform_tags  = local.common_tags
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-public-rt"
  vcn_id         = oci_core_virtual_network.oke.id
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.oke.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-private-rt"
  vcn_id         = oci_core_virtual_network.oke.id
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.oke.id
  }
}

# Permissive intra-VCN + API / SSH patterns; tighten for production.
resource "oci_core_security_list" "api" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-api-sl"
  vcn_id         = oci_core_virtual_network.oke.id
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
  vcn_id         = oci_core_virtual_network.oke.id
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
  vcn_id         = oci_core_virtual_network.oke.id
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
    source   = "0.0.0.0/0"
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
  vcn_id                     = oci_core_virtual_network.oke.id
  cidr_block                 = local.api_subnet_cidr
  display_name               = "${var.name_prefix}-k8s-api"
  dns_label                  = "k8sapi"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.api.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = local.common_tags
}

resource "oci_core_subnet" "lb" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_virtual_network.oke.id
  cidr_block                 = local.lb_subnet_cidr
  display_name               = "${var.name_prefix}-svc-lb"
  dns_label                  = "svclb"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.lb.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = local.common_tags
}

resource "oci_core_subnet" "workers" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_virtual_network.oke.id
  cidr_block                 = local.worker_subnet_cidr
  display_name               = "${var.name_prefix}-workers"
  dns_label                  = "workers"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.workers.id]
  prohibit_public_ip_on_vnic = true
  freeform_tags              = local.common_tags
}
