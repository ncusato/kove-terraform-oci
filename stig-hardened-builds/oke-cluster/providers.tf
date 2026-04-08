# OKE cluster stack (stig-hardened-builds/oke-cluster)
provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  region       = var.region
}
