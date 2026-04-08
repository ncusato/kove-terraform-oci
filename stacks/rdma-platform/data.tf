data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_vcns" "existing_vcns" {
  compartment_id = var.compartment_ocid
}

data "oci_core_subnet" "existing_public" {
  count     = var.use_existing_vcn ? 1 : 0
  subnet_id = var.existing_public_subnet_id
}

data "oci_core_subnet" "existing_management" {
  count     = var.use_existing_vcn ? 1 : 0
  subnet_id = var.existing_management_subnet_id
}

data "oci_core_subnet" "existing_rdma" {
  count     = var.use_existing_vcn ? 1 : 0
  subnet_id = var.existing_rdma_subnet_id
}

data "oci_core_images" "ol8_flex" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.E6.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
