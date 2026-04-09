output "vcn_id" {
  description = "VCN OCID."
  value       = oci_core_virtual_network.this.id
}

output "vcn_cidr" {
  description = "VCN IPv4 CIDR applied to this stack."
  value       = var.vcn_cidr_block
}

output "public_subnet_ocid" {
  description = "Public subnet OCID (Internet gateway route table)."
  value       = oci_core_subnet.public.id
}

output "public_subnet_cidr" {
  description = "Public subnet CIDR (index 1 within the VCN)."
  value       = local.public_subnet_cidr
}

output "private_subnet_ocids" {
  description = "Private subnet OCIDs in order: layout **one** has one entry; layout **two** is [mgmt-style, hpc-style]."
  value       = oci_core_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDRs in the same order as private_subnet_ocids."
  value       = local.private_subnet_cidrs
}

output "public_route_table_ocid" {
  description = "Route table attached to the public subnet (default route → Internet gateway)."
  value       = oci_core_route_table.public.id
}

output "private_route_table_ocid" {
  description = "Route table attached to private subnets (default route → NAT gateway)."
  value       = oci_core_route_table.private.id
}

output "internet_gateway_ocid" {
  description = "Internet gateway OCID."
  value       = oci_core_internet_gateway.this.id
}

output "nat_gateway_ocid" {
  description = "NAT gateway OCID."
  value       = oci_core_nat_gateway.this.id
}

output "service_gateway_ocid" {
  description = "Service gateway OCID (private subnets route Oracle Services Network here, oci-hpc pattern)."
  value       = oci_core_service_gateway.this.id
}

output "dhcp_options_ocid" {
  description = "Custom VCN DHCP options (VcnLocalPlusInternet + search domain, oci-hpc pattern)."
  value       = oci_core_dhcp_options.this.id
}

output "oracle_services_network_cidr" {
  description = "Oracle Services Network CIDR used in the private route table SERVICE_CIDR_BLOCK rule."
  value       = local.oracle_services_network.cidr_block
}

# Resource Manager: single copy-friendly block listing names + CIDRs after apply.
output "deployment_network_summary" {
  description = "Human-readable VCN and subnet layout for runbooks and ORM job output review."
  value       = <<-EOT
    HPC networking — ${local.consolidate_private ? "consolidated private subnet (management + RDMA)" : "separate private subnets (management + RDMA)"}
    VCN: ${local.vcn_name}
      CIDR: ${var.vcn_cidr_block}
      OCID: ${oci_core_virtual_network.this.id}

    Public subnet: ${local.public_subnet_name}
      CIDR: ${local.public_subnet_cidr}
      OCID: ${oci_core_subnet.public.id}
      Route table (IGW): ${oci_core_route_table.public.id}

    %{for i, name in local.private_subnet_names~}
    Private subnet ${i + 1}: ${name}
      CIDR: ${local.private_subnet_cidrs[i]}
      OCID: ${oci_core_subnet.private[i].id}
    %{endfor~}
    Private route table (NAT + Oracle Services via service gateway): ${oci_core_route_table.private.id}
    Service gateway: ${oci_core_service_gateway.this.id}
    DHCP options: ${oci_core_dhcp_options.this.id}
  EOT
}

output "network_cidrs_map" {
  description = "Structured map of CIDRs for automation (same values as deployment_network_summary)."
  value = {
    vcn             = var.vcn_cidr_block
    public          = local.public_subnet_cidr
    private_layout  = var.private_subnet_layout
    private_subnets = local.private_subnet_cidrs
    private_names   = local.private_subnet_names
  }
}
